# http://th3silverlining.com/lll12/04/22/using-the-heroku-shared-database-with-sinatra-and-active-record/
require "bundler/setup"
Bundler.require(:default)
require 'sinatra'
require 'haml'
require 'coffee-script'
require './models'

get '/' do
  return haml :users, :locals => {:users => Account.find(:all)} unless params[:user_id]
  user = Account.find(params[:user_id])
  haml :index, :locals => {:account => user, :loading => user.messages.count < user.message_count}
end

get '/data/contacts.json' do
  user = Account.find(params[:user_id])
  return "No account for #{user}" unless user
  start_date = user.messages.where('date IS NOT NULL AND date > "1975-01-01"').first(:order => :date).date.beginning_of_year
  end_date = user.messages.last(:order => 'date').date
  start_date = parse_date(params[:since] || params[:after]) if params[:since] or params[:after]
  end_date = parse_date(params[:before] || params[:until]) if params[:before] or params[:until]
  limit = (params[:limit] || 20).to_i
  stats = {}
  map = {}
  while start_date < end_date
    next_date = start_date + 1.week
    results = Message.connection.select_all(<<-"SQL", nil, [[nil, user.id], [nil, start_date], [nil, next_date]])
      SELECT address, addresses.id, addresses.person_id, COUNT(*) AS count FROM addresses
      JOIN message_associations ON address_id=addresses.id
      JOIN messages ON message_id=messages.id
      WHERE messages.account_id = $1 AND $2 <= messages.date AND messages.date < $3
      AND HOST IS NOT NULL
      AND addresses.id != $1 AND (person_id IS NULL OR person_id != $1)
      GROUP BY (CASE WHEN person_id THEN person_id ELSE addresses.id END)
      ORDER BY COUNT(*) DESC
      LIMIT 15
    SQL
    for record in results
      record["address"] = map[record["person_id"]] ||= Address.find(record["person_id"]).address if record["person_id"] and record["person_id"] != record["id"]
    end
    stats[start_date.strftime("%Y-%m")] = results.inject({}) { |h, r| h[r["address"].to_s] = r["count"]; h }
    start_date = next_date
  end
  names = stats.map { |date, counts| counts.keys }.flatten.uniq
  names = names.inject({}) do |h, name|
    h[name] = stats.map { |_, x| x[name] }.compact.sum
    h
  end.to_a.sort { |a, b| b[1] <=> a[1] }[0...limit].map { |name, _| name }
  series = names.map do |name|
    {
      :key => name,
      :values => stats.map { |date, x| {date: date, count: x[name] || 0} }
    }
  end
  content_type :json
  series.to_json
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

get '/flow' do
  user = Account.find(params[:user_id])
  haml :flow, :locals => {:user => user}
end

get "/js/*.coffee.js" do
  coffee params[:splat].first.to_sym
end

get(/.+/) do
  send_sinatra_file(request.path) {404}
end

BUILD_DIR = '.'

def send_sinatra_file(path, &missing_file_block)
  file_path = File.join(File.dirname(__FILE__), BUILD_DIR,  path)
  file_path = File.join(file_path, 'index.html') unless file_path =~ /\.[a-z]+$/i
  File.exist?(file_path) ? send_file(file_path) : missing_file_block.call
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
