require 'google/api_client'
require 'google/api_client/client_secrets'

def auth(options)
  options = {:request => options} if options.is_a?(Sinatra::Request)
  scope = options[:scope] || ['https://mail.google.com/', 'https://www.googleapis.com/auth/userinfo.email']
  redirect_uri = options[:redirect_uri]
  redirect_uri ||= "#{options[:request].scheme}://#{options[:request].host_with_port}/oauth2callback" if options[:request]
  Signet::OAuth2::Client.new(
    :authorization_uri => "https://accounts.google.com/o/oauth2/auth",
    :token_credential_uri => "https://accounts.google.com/o/oauth2/token",
    :client_id => google_oauth_client_id,
    :client_secret => google_oauth_client_secret,
    :redirect_uri => redirect_uri,
    :scope => scope)
end

def google_oauth_client_id
  ENV['GOOGLE_OAUTH_CLIENT_ID'] || "641654287458-ftci0053g696ods8r6j0bvjadcsumlub.apps.googleusercontent.com"
end

def google_oauth_client_secret
  ENV['GOOGLE_OAUTH_CLIENT_SECRET'] || "pyaC6-Qjaji1Zx1otZKsb82b"
end


get '/account/signin' do
  oauth_uri = auth(request).authorization_uri
  redirect to(oauth_uri.to_s)
end

get '/account/signout' do
  session[:user_id] = nil
  redirect to("/")
end

get '/oauth2callback' do
  auth = auth(request)
  auth.code = params[:code]
  auth.fetch_access_token!
  data = HTTParty.get("https://www.googleapis.com/oauth2/v1/userinfo", :query => {:alt => :json, :access_token => auth.access_token}).parsed_response
  email = data['email']
  record = Token.where(:email_address => email).first_or_initialize
  record.update_attributes :access_token => auth.access_token, :refresh_token => auth.refresh_token, :expires_at => auth.issued_at + auth.expires_in.seconds
  user = Account.find_by_email_address(email)
  if user
    session[:user_id] = user.id
    redirect to('/')
  else
    redirect to('/waitlist')
  end
end
