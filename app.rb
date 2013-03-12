# http://th3silverlining.com/lll12/04/22/using-the-heroku-shared-database-with-sinatra-and-active-record/
require "bundler/setup"
Bundler.require(:default)
require 'sinatra'
require 'haml'
require 'coffee-script'
require './models'
require './email_analyzer'

redis = Redis.new

get '/' do
  return haml :users, :locals => {:users => Account.find(:all)} unless params[:user_id]
  user = Account.find(params[:user_id])
  haml :index, :locals => {:account => user, :loading => user.messages.count < user.message_count}
end

get '/flow' do
  user = Account.find(params[:user_id])
  haml :flow, :locals => {:user => user}
end

get '/data/contacts.json' do
  path = request.path
  user = Account.find(params[:user_id])
  return "No account for #{user}" unless user
  start_date = parse_date(params[:since] || params[:after]) if params[:since] or params[:after]
  end_date = parse_date(params[:before] || params[:until]) if params[:before] or params[:until]
  limit = (params[:limit] || 20).to_i
  redis[path] = nil if params.include?("nocache")
  json = redis[path]
  # return json.inspect
  unless json and json != ""
    series = EmailAnalyzer.new(user).series(start_date, end_date, limit)
    json = series.to_json
    redis[path] = json
    # redis.expire(id, 3600*24*5)
  end
  content_type :json
  json
end

get '/me' do
  user = Account.find(params[:user_id])
  address = Address.find(params[:address_id])
  person = Address.first(:conditions => {:address => user.user})
  person = Address.find(address.person_id) if address.person_id and address.person_id != address.id
  Address.update_all({:person_id => person.id}, {:address => address.address})
  Address.update_all({:person_id => person.id}, {:person_id => address.person_id}) if address.person_id
  redirect to("/?user_id=#{user.id}")
end

get "/js/*.coffee.js" do
  coffee params[:splat].first.to_sym
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
