require './app'

$stdout.sync = true if ENV['RACK_ENV'] == 'production'

map '/' do
  run Sinatra::Application
end

# run Rack::URLMap.new \
#      "/"       => Sinatra::Application
#      "/resque" => Resque::Server.new
