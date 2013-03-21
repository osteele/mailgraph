require './app'

map '/' do
  run Sinatra::Application
end

# run Rack::URLMap.new \
#      "/"       => Sinatra::Application
#      "/resque" => Resque::Server.new
