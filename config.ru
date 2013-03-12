require './app'

run Sinatra::Application

# run Rack::URLMap.new \
     # "/"       => Sinatra::Application
     # "/resque" => Resque::Server.new
