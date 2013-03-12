require 'thin'
require 'launchy'
require 'httparty'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'active_support'
require './models'

# Small helper for the sample apps for performing OAuth 2.0 flows from the command
# line. Starts an embedded server to handle redirects.
class CommandLineOAuthHelper
  def initialize(scope)
    credentials = Google::APIClient::ClientSecrets.load
    @authorization = Signet::OAuth2::Client.new(
      :authorization_uri => credentials.authorization_uri,
      :token_credential_uri => credentials.token_credential_uri,
      :client_id => credentials.client_id,
      :client_secret => credentials.client_secret,
      :redirect_uri => credentials.redirect_uris.first,
      :scope => scope)
  end

  # Request authorization. Opens a browser and waits for response
  def authorize
    auth = @authorization
    url = auth.authorization_uri().to_s
    server = Thin::Server.new('0.0.0.0', 3000) do
      run lambda { |env|
        # Exchange the auth code & quit
        req = Rack::Request.new(env)
        auth.code = req['code']
        auth.fetch_access_token!
        server.stop()
        [200, {'Content-Type' => 'text/plain'}, 'OK']
      }
    end

    Launchy.open(url)
    server.start()

    return @authorization
  end
end

auth = CommandLineOAuthHelper.new(['https://mail.google.com/', 'https://www.googleapis.com/auth/userinfo.email']).authorize
data = HTTParty.get("https://www.googleapis.com/oauth2/v1/userinfo", :query => {:alt => :json, :access_token => auth.access_token}).parsed_response
email = data['email']

record = Token.where(:email_address => email).first_or_initialize
record.assign_attributes :access_token => auth.access_token, :refresh_token => auth.refresh_token, :expires_at => auth.issued_at + auth.expires_in.seconds
record.save!
