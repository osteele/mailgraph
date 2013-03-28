require 'bundler/setup'
require 'pry'
require 'nokogiri'
require 'httparty'
require 'ostruct'
require './config/environments'
require './oauth_utils'

email_address = 'oliver.steele@gmail.com'
access_token = GoogleOAuthToken::find_access_token_by_email_address(email_address)

DEFAULT_GOOGLE_OAUTH_CLIENT_ID = '641654287458-ftci0053g696ods8r6j0bvjadcsumlub.apps.googleusercontent.com'
GOOGLE_OAUTH_CLIENT_ID = ENV['GOOGLE_OAUTH_CLIENT_ID'] || DEFAULT_GOOGLE_OAUTH_CLIENT_ID

def read_contacts(access_token, limit=300, offset=0)
  client_id = GOOGLE_OAUTH_CLIENT_ID
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
    etag = item.attributes['etag'].inner_text.gsub('"', '')
    name = item.xpath('./title')[0].children.inner_text
    addresses = item.xpath('./email').map { |email| email.attributes['address'].inner_text }

    contact = OpenStruct.new({
      :uid => etag,
      :name => name,
      :addresses => addresses,
      :primary_address => item.xpath('./email[@primary]').map { |email| email.attributes['address'].inner_text }.first
    })
  end
end

def for_all_contacts(access_token, &block)
  offset = 0
  limit = 300
  begin
    entries = read_contacts(access_token, limit, offset)
    entries.each &block
    offset += entries.length
  end while entries.length == limit
end

account = Account.where(:email_address => email_address).first_or_create!
for_all_contacts(access_token) do |contact|
  record = Contact.where(:account_id => account, :uid => contact.uid).first_or_initialize
  puts "Creating contact #{contact.uid} #{contact.name}" unless record.id
  record.transaction do
    record.name = contact.name
    record.primary_address = contact.primary_address ? Address.from_string(contact.primary_address) : nil
    record.save! if record.changed? or record.id.nil?
    addresses = contact.addresses.map { |email| Address.from_string(email) }
    unless record.addresses.pluck(:id) == addresses.map(&:id)
      puts "Creating contact #{contact.uid} #{contact.name}" unless record.id
      record.addresses = addresses
    end
  end
end
