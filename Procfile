web: bundle exec rackup config.ru -p $PORT
worker: bundle exec rake resque:work TERM_CHILD=1 RESQUE_TERM_TIMEOUT=600
#scheduler: bundle exec rake resque:scheduler
