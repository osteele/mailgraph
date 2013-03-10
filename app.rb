# http://th3silverlining.com/2012/04/22/using-the-heroku-shared-database-with-sinatra-and-active-record/
require "bundler/setup"
Bundler.require(:default)
require 'sinatra'
require 'haml'
require 'coffee-script'
require './models'

get '/' do
  haml :index, :locals => {:account => Account.find_by_user('oliver.steele@gmail.com')}
end

get '/data/contacts.json' do
  account = Account.find_by_user('oliver.steele@gmail.com')
  start_date = account.messages.where('date IS NOT NULL AND date > "1975-01-01"').first(:order => :date).date.beginning_of_year
  end_date = account.messages.last(:order => 'date').date
  stats = {}
  while start_date < end_date
    next_date = start_date + 1.month
    results = Message.connection.select_all(<<-"SQL", nil, [[nil, start_date], [nil, next_date]])
      SELECT address, COUNT(*) AS count FROM addresses
      JOIN message_associations ON address_id=addresses.id
      JOIN messages ON message_id=messages.id
      WHERE messages.date > $1 AND messages.date < $2
      AND HOST IS NOT NULL
      AND address NOT LIKE 'steele@%' AND address NOT LIKE 'oliver.steele@%' AND address NOT LIKE 'osteele@%'
      GROUP BY address
      ORDER BY COUNT(*) DESC
      LIMIT 10
    SQL
    stats[start_date.strftime("%Y-%m")] = results.inject({}) { |h, r| h[r["address"]] = r["count"]; h }
    start_date = next_date
  end
  names = stats.map { |date, counts| counts.keys }.flatten.uniq
  names = names.inject({}) do |h, name|
    h[name] = stats.map { |_, x| x[name] }.compact.sum
    h
  end.to_a.sort { |a, b| b[1] <=> a[1] }[0...25].map { |name, _| name }
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
