web: bundle exec rails server | ./bin/pretty-json-logs
worker: bundle exec sidekiq -q sms -q voice -q mailers -q analytics
mail: bundle exec mailcatcher -f
