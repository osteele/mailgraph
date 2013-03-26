require 'google/api_client'
require 'logger'
require './models'
require './utils'

class GoogleOAuthToken
  include Logging

  def self.find_by_email_address(email_address)
    return self.new(email_address)
  end

  def self.find_access_token_by_email_address(email_address)
    return self.find_by_email_address(email_address).access_token
  end

  attr_reader :email_address, :token_record

  def initialize(email_address)
    @email_address = email_address
  end

  def access_token
    self.renew! if self.expired?
    return token_record.access_token
  end

  def expired?(lead_time=30.seconds)
    return token_record.expires_at < Time.now + lead_time
  end

  def renew!
    self.logger.info "Renewing token for #{email_address}"
    client = Google::APIClient.new(:application_name => "Mailgraph", :application_version => "0.1")
    auth = client.authorization
    auth.client_id = google_oauth_client_id
    auth.client_secret = google_oauth_client_secret
    auth.redirect_uri = "urn:ietf:oauth:2.0:oob"
    auth.scope = ['https://mail.google.com/', 'https://www.googleapis.com/auth/userinfo.email']

    auth.update_token! :access_token => token_record.access_token, :refresh_token => token_record.refresh_token
    auth.fetch_access_token!
    token_record.update_attributes :access_token => auth.access_token, :expires_at => auth.issued_at + auth.expires_in.seconds
  end

  private

  def token_record
    @token_record ||= Token.find_by_email_address(email_address)
    raise "No access token for #{email_address}" unless @token_record
    @token_record
  end

  def google_oauth_client_id
    ENV['GOOGLE_OAUTH_CLIENT_ID'] || DEFAULT_GOOGLE_OAUTH_CLIENT_ID
  end

  def google_oauth_client_secret
    ENV['GOOGLE_OAUTH_CLIENT_SECRET'] || DEFAULT_GOOGLE_OAUTH_CLIENT_SECRET
  end

  DEFAULT_GOOGLE_OAUTH_CLIENT_ID = '641654287458-ftci0053g696ods8r6j0bvjadcsumlub.apps.googleusercontent.com'
  DEFAULT_GOOGLE_OAUTH_CLIENT_SECRET = 'pyaC6-Qjaji1Zx1otZKsb82b'
end
