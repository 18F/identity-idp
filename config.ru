# This file is used by Rack-based servers to start the application.

# Don't buffer stdout.  We want logs to be available in real time.
# See: https://devcenter.heroku.com/articles/logging#writing-to-your-log
# If we end up using the rails_12factor gem, we can remove this, as it provides
# this functionality.
STDOUT.sync = true

require ::File.expand_path('../config/environment', __FILE__)

run Rails.application
