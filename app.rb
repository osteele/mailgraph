# http://th3silverlining.com/2012/04/22/using-the-heroku-shared-database-with-sinatra-and-active-record/
require "bundler/setup"
Bundler.require(:default)
require 'sinatra'
require 'haml'
require 'coffee-script'
require './config/resque.rb'

get '/' do
  haml :index
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
