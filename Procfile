web: ruby app.rb
#resque-web: resque-web --foreground
#resque: rake jobs:work
worker: bundle exec rake resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=600
