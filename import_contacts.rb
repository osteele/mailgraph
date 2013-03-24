require "bundler/setup"
require 'nokogiri'
require 'httparty'
require 'ostruct'
require './config/environments'
require './oauth_utils'

email_address = 'oliver.steele@gmail.com'
access_token = GoogleOAuthToken::find_access_token_by_email_address(email_address)

DEFAULT_GOOGLE_OAUTH_CLIENT_ID = '641654287458-ftci0053g696ods8r6j0bvjadcsumlub.apps.googleusercontent.com'
GOOGLE_OAUTH_CLIENT_ID = ENV['GOOGLE_OAUTH_CLIENT_ID'] || DEFAULT_GOOGLE_OAUTH_CLIENT_ID

def read_contacts(access_token, limit=4, offset=0)
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
    email_addresses = item.xpath('./email').map { |email|
      email.attributes['address'].inner_text
    }

    contact = OpenStruct.new({
      :uid => etag,
      :name => name,
      :emails => email_addresses
    })
  end
end

require 'pp'
pp read_contacts(access_token, 100).sort_by(&:name)
