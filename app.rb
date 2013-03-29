require "bundler/setup"
Bundler.require(:default)
require 'digest/sha1'
require 'sinatra'
require 'haml'
require 'coffee-script'
require './config/environments'
require './models'
require './email_analyzer'
require './oauth_routes'
require './assets'

redis = Redis.new

enable :sessions
set :session_secret, "ic8cop5mewm7eb4i"

before '/user/:user_id' do authenticate! end
before '/user/:user_id/*' do authenticate! end
before '/admin/*' do authenticate_admin! end

def authenticate!
  @user = Account.find(session[:user_id]) if session[:user_id]
  redirect to("/account/signin") and halt unless @user
  redirect to("/waitlist") and halt unless @user.active
  halt 403 unless params[:user_id] == @user.id.to_s or @user.admin
  @user = Account.find(params[:user_id]) unless params[:user_id] == @user.id
end

def authenticate_admin!
  @user = Account.find(session[:user_id]) if session[:user_id]
  redirect to("/account/signin") and halt unless @user
  halt 403 unless @user.admin
end

get '/' do
  redirect to("/user/#{session[:user_id]}") if session[:user_id]
  redirect to("/account/signin")
end

get '/waitlist' do
  session[:user_id] = nil
  haml :waitlist
end

get '/admin/users' do
  return haml :users, :locals => {:users => Account.find(:all)}
end

get '/user/:id' do
  haml :index, :locals => {:user => @user, :loading => @user.message_count && @user.messages.count < @user.message_count}
end

get '/user/:id/flow' do
  haml :flow, :locals => {:user => @user}
end

get '/user/:id/bubble' do
  haml :bubble, :locals => {:user => @user}
end

def cached(redis, request, params, &block)
  redis_key = "url:#{request.path}"
  redis[redis_key] = nil if params[:cache] == "false"
  value = redis[redis_key]
  value = nil if value == ""
  unless value
    value = yield
    redis[redis_key] = value
  end
  value
end

get '/user/:id/contacts.json' do
  start_date = parse_date(params[:since] || params[:after]) if params[:since] or params[:after]
  end_date = parse_date(params[:before] || params[:until]) if params[:before] or params[:until]
  limit = (params[:limit] || 20).to_i
  json = cached(redis, request, params) do
    series = EmailAnalyzer.new(@user).series(:start => start_date, :end => end_date, :limit => limit, :by_interval => params[:by_interval])
    series.to_json
  end
  etag Digest::SHA1.hexdigest(json)
  content_type :json
  json
end

get '/user/:id/me' do
  address = Address.find(params[:address_id])
  person = Address.first(:conditions => {:address => @user.email_address})
  person = Address.find(address.canonical_address_id) if address.canonical_address_id and address.canonical_address_id != address.id
  Address.update_all({:canonical_address_id => person.id}, {:address => address.address})
  Address.update_all({:canonical_address_id => person.id}, {:canonical_address_id => address.canonical_address_id}) if address.canonical_address_id
  redirect to("/user/#{user.id}")
end

class Fixnum
  def commas
    to_s.reverse.gsub(/(\d\d\d)/, '\1,').reverse.sub(/^,/, '')
  end
end

def parse_date(s)
  s = "01/#{s}" if s =~ /^\d{4}$/
  Chronic.parse(s)
end
