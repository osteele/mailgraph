require "bundler/setup"
Bundler.require(:default)
require 'sinatra/activerecord/rake'
require 'resque/tasks'
# require 'resque_scheduler/tasks'
require 'resque-loner'
require './app'
require './import'

task "resque:setup" do
  ENV['QUEUE'] = '*'
  Resque.before_fork = Proc.new do
    ActiveRecord::Base.establish_connection('development')
    ActiveRecord::Base.verify_active_connections!
  end
end

desc "Alias for resque:work (to run workers on Heroku)"
task "jobs:work" => "resque:work"
