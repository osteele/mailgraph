# http://th3silverlining.com/lll12/04/22/using-the-heroku-shared-database-with-sinatra-and-active-record/
require "bundler/setup"
Bundler.require(:default)
require 'sinatra'
require 'haml'
require 'coffee-script'
require './models'

get '/' do
  user = params["user"] || 'oliver.steele@gmail.com'
  account = Account.find_by_user(user)
  return "No account for #{user}" unless account
  haml :index, :locals => {:account => account}
end

get '/data/contacts.json' do
  user = params[:user] || 'oliver.steele@gmail.com'
  account = Account.find_by_user(user)
  return "No account for #{user}" unless account
  start_date = account.messages.where('date IS NOT NULL AND date > "1975-01-01"').first(:order => :date).date.beginning_of_year
  end_date = account.messages.last(:order => 'date').date
  start_date = parse_date(params[:since] || params[:after]) if params[:since] or params[:after]
  end_date = parse_date(params[:before] || params[:until]) if params[:before] or params[:until]
  limit = (params[:limit] || 20).to_i
  stats = {}
  map = {}
  exceptions = "address NOT LIKE 'steele@%' AND address NOT LIKE 'oliver.steele@%' AND address NOT LIKE 'osteele@%'"
  exceptions = "address NOT LIKE 'marg@%' AND address NOT LIKE 'margaret.minsky@%'" if user =~ /^margaret\.minsky@/
  while start_date < end_date
    next_date = start_date + 1.week
    results = Message.connection.select_all(<<-"SQL", nil, [[nil, account.id], [nil, start_date], [nil, next_date]])
      SELECT address, addresses.person_id, addresses.id, COUNT(*) AS count FROM addresses
      JOIN message_associations ON address_id=addresses.id
      JOIN messages ON message_id=messages.id
      WHERE messages.account_id = $1 AND messages.date > $2 AND messages.date < $3
      AND HOST IS NOT NULL
      AND #{exceptions}
      GROUP BY (CASE WHEN addresses.person_id IS NULL THEN addresses.id ELSE addresses.person_id END)
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

get '/flow' do
  haml :flow
end

get "/js/flow.js" do
  coffee :flow
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
