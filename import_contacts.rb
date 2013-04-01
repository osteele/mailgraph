require 'bundler/setup'
require 'pry'
require 'nokogiri'
require 'httparty'
require 'ostruct'
require './config/environments'
require './oauth_utils'

class Contacts
  DEFAULT_GOOGLE_OAUTH_CLIENT_ID = '641654287458-ftci0053g696ods8r6j0bvjadcsumlub.apps.googleusercontent.com'
  GOOGLE_OAUTH_CLIENT_ID = ENV['GOOGLE_OAUTH_CLIENT_ID'] || DEFAULT_GOOGLE_OAUTH_CLIENT_ID

  attr_reader :email_address

  def initialize(email_address)
    @email_address = email_address
  end

  def access_token
    access_token = GoogleOAuthToken::find_access_token_by_email_address(email_address)
  end

  def read_contacts(limit=300, offset=0)
    client_id = GOOGLE_OAUTH_CLIENT_ID
    # Parameters documented https://developers.google.com/google-apps/domain-shared-contacts/#Parameters
    url = 'https://www.google.com/m8/feeds/contacts/default/full'
    query = {
      :v => '3.0',
      client_id: client_id,
      :access_token => access_token,
      'start-index' => offset + 1,
      'max-results' => limit
    }
    response = HTTParty.get(url, :query => query)
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    doc.xpath('//entry').map do |item|
      id = item.xpath('./id').inner_text.split('/').last
      name = item.xpath('./title')[0].children.inner_text
      addresses = item.xpath('./email').map { |email| email.attributes['address'].inner_text }

      contact = OpenStruct.new({
        :uid => id,
        :name => name,
        :addresses => addresses,
        :primary_address => item.xpath('./email[@primary]').map { |email| email.attributes['address'].inner_text }.first,
        :xml => item.to_xml
      })
    end
  end

  def each(options={}, &block)
    offset = options[:offset] || 0
    limit = options[:limit] || 300
    while offset < limit
      entries = read_contacts(limit, offset)
      entries.each &block
      offset += entries.length
    end
  end
end

def update_contacts(email_address)
  account = Account.where(:email_address => email_address).first_or_create!
  contacts = Contacts.new(email_address)

  contact_uids = []
  contacts.each do |contact|
    contact_uids << contact.uid
    record = Contact.where(:account_id => account, :uid => contact.uid).first_or_initialize
    created = record.id.nil?
    puts "Creating contact #{contact.name}" if created
    record.transaction do
      record.name = contact.name
      record.primary_address = contact.primary_address ? Address.from_string(contact.primary_address) : nil
      record.save! if record.changed? or record.id.nil?
      addresses = contact.addresses.map { |email| Address.from_string(email) }
      unless record.addresses.pluck(:id) == addresses.map(&:id)
        puts "Updating addresses for #{record.id} #{contact.uid} #{contact.name}" unless created
        record.addresses = addresses
      end
    end
  end

  deleted_contact_uids = Contact.where(:account_id => account.id).pluck(:uid) - contact_uids
  if deleted_contact_uids.any?
    puts "Deleting #{deleted_contact_uids.length} contacts"
    Contact.where(:account_id => account.id, :uid => deleted_contact_uids).destroy_all
  end
end

# TODO increment since updated-min
update_contacts('oliver.steele@gmail.com')

# Contacts.new('oliver.steele@gmail.com').each(:limit => 1) do |r|
#   puts r.xml
# end
