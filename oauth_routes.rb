require 'google/api_client'
require 'google/api_client/client_secrets'

def auth
  Signet::OAuth2::Client.new(
    :authorization_uri => "https://accounts.google.com/o/oauth2/auth",
    :token_credential_uri => "https://accounts.google.com/o/oauth2/token",
    :client_id => ENV['GOOGLE_OAUTH_CLIENT_ID'] || "641654287458-ftci0053g696ods8r6j0bvjadcsumlub.apps.googleusercontent.com",
    :client_secret => ENV['GOOGLE_OAUTH_CLIENT_SECRET'] || "pyaC6-Qjaji1Zx1otZKsb82b",
    :redirect_uri => "#{ENV['GOOGLE_OAUTH_ORIGIN'] || 'http://localhost:3000'}/oauth2callback"
    :scope => scope)
end

get '/auth' do
    return request.env.inspect
  redirect to(auth.authorization_uri().to_s)
end

get '/oauth2callback' do
  auth = auth()
  auth.code = params[:code]
  auth.fetch_access_token!
  data = HTTParty.get("https://www.googleapis.com/oauth2/v1/userinfo", :query => {:alt => :json, :access_token => auth.access_token}).parsed_response
  email = data['email']
  record = Token.where(:email_address => email).find_or_initialize
  record.update_attributes :access_token => auth.access_token, :refresh_token => auth.refresh_token, :expires_at => auth.issued_at + auth.expires_in.seconds
end
