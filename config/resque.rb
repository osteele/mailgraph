require 'resque'
# require 'resque-sentry'
# require 'resque/failure/multiple'
require 'resque/failure/redis'
require 'resque/server'

ENV["REDISTOGO_URL"] ||= "redis://localhost/"

uri = URI.parse(ENV["REDISTOGO_URL"])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :thread_safe => true)

Resque::Failure::Multiple.classes = [Resque::Failure::Redis] # Resque::Failure::Sentry
Resque::Failure.backend = Resque::Failure::Multiple
# Resque.inline = true

Resque::Server.class_eval do
  use Rack::Auth::Basic do |email, password|
    user = User.find_by_email(email)
    user && user.valid_password?(password) && user.admin?
  end
end
