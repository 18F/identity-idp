# frozen_string_literal: true

# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 1 threads for minimum
# and maximum;
max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 1)
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies that the worker count should equal the number of processors in production.
if ENV['RAILS_ENV'] == 'production'
  require 'concurrent-ruby'
  worker_count = Integer(
    ENV.fetch('PUMA_WORKER_CONCURRENCY') { Concurrent.physical_processor_count },
  )
  workers worker_count if worker_count > 1

  if ENV['REMOTE_ADDRESS_HEADER']
    set_remote_address header: ENV['REMOTE_ADDRESS_HEADER']
  end
end

# Write Puma logs to file in append mode
if ENV['PUMA_LOG'] && ENV['PUMA_LOG_ERR']
  stdout_redirect ENV['PUMA_LOG'], ENV['PUMA_LOG_ERR'], true
end

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if ENV.fetch('RAILS_ENV', 'development') == 'development'

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch('PORT', 3000)

# Specifies the `environment` that Puma will run in.
environment ENV.fetch('RAILS_ENV', 'development')

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch('PIDFILE', 'tmp/pids/server.pid')

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
