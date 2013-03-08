web: ruby app.rb
#resque-web: resque-web --foreground
worker: bundle exec rake resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=600
#scheduler: bundle exec rake resque:scheduler
