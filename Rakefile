require "bundler/setup"
Bundler.require(:default)
require 'sinatra/activerecord/rake'
require 'resque/tasks'
#require 'resque_scheduler/tasks'
require './app'
require './import'

task "resque:setup" do
  ENV['QUEUE'] = '*'
  Resque.before_fork = Proc.new do
    ActiveRecord::Base.establish_connection('development')
    ActiveRecord::Base.verify_active_connections!
  end
end

desc "Schedule and work, so we only need 1 dyno"
task :schedule_and_work do
  if Process.fork
    sh "rake environment resque:work"
  else
    sh "rake resque:scheduler"
    Process.wait
  end
end
