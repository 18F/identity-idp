# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `rack-timeout` gem.
# Please instead update this file by running `bin/tapioca gem rack-timeout`.


# can be required by other files to prevent them from having to open and nest Rack and Timeout
#
# source://rack-timeout//lib/rack/timeout/support/namespace.rb#2
module Rack
  class << self
    # source://rack/3.0.11/lib/rack/version.rb#31
    def release; end

    # source://rack/3.0.11/lib/rack/version.rb#23
    def version; end
  end
end

# source://rack-timeout//lib/rack/timeout/support/namespace.rb#3
class Rack::Timeout
  include ::Rack::Timeout::MonotonicTime

  # @return [Timeout] a new instance of Timeout
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#69
  def initialize(app, service_timeout: T.unsafe(nil), wait_timeout: T.unsafe(nil), wait_overtime: T.unsafe(nil), service_past_wait: T.unsafe(nil), term_on_timeout: T.unsafe(nil)); end

  # source://rack-timeout//lib/rack/timeout/core.rb#85
  def call(env); end

  # helper methods to read timeout properties. Ensure they're always positive numbers or false. When set to false (or 0), their behaviour is disabled.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#51
  def read_timeout_property(value, default); end

  # Returns the value of attribute service_past_wait.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#62
  def service_past_wait; end

  # Returns the value of attribute service_timeout.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#62
  def service_timeout; end

  # Returns the value of attribute term_on_timeout.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#62
  def term_on_timeout; end

  # Returns the value of attribute wait_overtime.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#62
  def wait_overtime; end

  # Returns the value of attribute wait_timeout.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#62
  def wait_timeout; end

  class << self
    # source://rack-timeout//lib/rack/timeout/core.rb#176
    def _read_x_request_start(env); end

    # This method determines if a body is present. requests with a body (generally POST, PUT) can have a lengthy body which may have taken a while to be received by the web server, inflating their computed wait time. This in turn could lead to unwanted expirations. See wait_overtime property as a way to overcome those.
    # This is a code extraction for readability, this method is only called from a single point.
    #
    # @return [Boolean]
    #
    # source://rack-timeout//lib/rack/timeout/core.rb#184
    def _request_has_body?(env); end

    # source://rack-timeout//lib/rack/timeout/core.rb#191
    def _set_state!(env, state); end

    # Sends out the notifications. Called internally at the end of `_set_state!`
    #
    # source://rack-timeout//lib/rack/timeout/core.rb#216
    def notify_state_change_observers(env); end

    # Registers a block to be called back when a request changes state in rack-timeout. The block will receive the request's env.
    #
    # `id` is anything that uniquely identifies this particular callback, mostly so it may be removed via `unregister_state_change_observer`.
    #
    # @raise [RuntimeError]
    #
    # source://rack-timeout//lib/rack/timeout/core.rb#203
    def register_state_change_observer(id, &callback); end

    # Removes the observer with the given id
    #
    # source://rack-timeout//lib/rack/timeout/core.rb#210
    def unregister_state_change_observer(id); end
  end
end

# key where request id is stored if generated by action dispatch
#
# source://rack-timeout//lib/rack/timeout/core.rb#48
Rack::Timeout::ACTION_DISPATCH_REQUEST_ID = T.let(T.unsafe(nil), String)

# key under which each request's RequestDetails instance is stored in its env.
#
# source://rack-timeout//lib/rack/timeout/core.rb#46
Rack::Timeout::ENV_INFO_KEY = T.let(T.unsafe(nil), String)

# source://rack-timeout//lib/rack/timeout/core.rb#18
class Rack::Timeout::Error < ::RuntimeError
  include ::Rack::Timeout::ExceptionWithEnv
end

# shared by the following exceptions, allows them to receive the current env
#
# source://rack-timeout//lib/rack/timeout/core.rb#11
module Rack::Timeout::ExceptionWithEnv
  # source://rack-timeout//lib/rack/timeout/core.rb#13
  def initialize(env); end

  # Returns the value of attribute env.
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#12
  def env; end
end

# key where request id is stored if generated by upstream client/proxy
#
# source://rack-timeout//lib/rack/timeout/core.rb#47
Rack::Timeout::HTTP_X_REQUEST_ID = T.let(T.unsafe(nil), String)

# source://rack-timeout//lib/rack/timeout/core.rb#175
Rack::Timeout::HTTP_X_REQUEST_START = T.let(T.unsafe(nil), String)

# source://rack-timeout//lib/rack/timeout/logger.rb#5
module Rack::Timeout::Logger
  extend ::Rack::Timeout::Logger

  # Returns the value of attribute device.
  #
  # source://rack-timeout//lib/rack/timeout/logger.rb#7
  def device; end

  # source://rack-timeout//lib/rack/timeout/logger.rb#9
  def device=(new_device); end

  # source://rack-timeout//lib/rack/timeout/logger.rb#27
  def disable; end

  # source://rack-timeout//lib/rack/timeout/logger.rb#21
  def init; end

  # Returns the value of attribute level.
  #
  # source://rack-timeout//lib/rack/timeout/logger.rb#7
  def level; end

  # source://rack-timeout//lib/rack/timeout/logger.rb#13
  def level=(new_level); end

  # Returns the value of attribute logger.
  #
  # source://rack-timeout//lib/rack/timeout/logger.rb#7
  def logger; end

  # source://rack-timeout//lib/rack/timeout/logger.rb#17
  def logger=(new_logger); end

  # source://rack-timeout//lib/rack/timeout/logger.rb#32
  def update(new_device, new_level); end
end

# lifted from https://github.com/ruby-concurrency/concurrent-ruby/blob/master/lib/concurrent/utility/monotonic_time.rb
#
# source://rack-timeout//lib/rack/timeout/support/monotonic_time.rb#5
module Rack::Timeout::MonotonicTime
  extend ::Rack::Timeout::MonotonicTime

  # source://rack-timeout//lib/rack/timeout/support/monotonic_time.rb#8
  def fsecs; end

  # source://rack-timeout//lib/rack/timeout/support/monotonic_time.rb#12
  def fsecs_java; end

  # source://rack-timeout//lib/rack/timeout/support/monotonic_time.rb#8
  def fsecs_mono; end

  # source://rack-timeout//lib/rack/timeout/support/monotonic_time.rb#18
  def fsecs_ruby; end
end

# shorthand reference
#
# source://rack-timeout//lib/rack/timeout/core.rb#84
Rack::Timeout::RT = Rack::Timeout

# source://rack-timeout//lib/rack/timeout/core.rb#174
Rack::Timeout::RX_HEROKU_X_REQUEST_START = T.let(T.unsafe(nil), Regexp)

# X-Request-Start contains the time the request was first seen by the server. Format varies wildly amongst servers, yay!
#   - nginx gives the time since epoch as seconds.milliseconds[1]. New Relic documentation recommends preceding it with t=[2], so might as well detect it.
#   - Heroku gives the time since epoch in milliseconds. [3]
#   - Apache uses t=microseconds[4], so we're not even going there.
#
# The sane way to handle this would be by knowing the server being used, instead let's just hack around with regular expressions and ignore apache entirely.
# [1]: http://nginx.org/en/docs/http/ngx_http_log_module.html#var_msec
# [2]: https://docs.newrelic.com/docs/apm/other-features/request-queueing/request-queue-server-configuration-examples#nginx
# [3]: https://devcenter.heroku.com/articles/http-routing#heroku-headers
# [4]: http://httpd.apache.org/docs/current/mod/mod_headers.html#header
#
# This is a code extraction for readability, this method is only called from a single point.
#
# source://rack-timeout//lib/rack/timeout/core.rb#173
Rack::Timeout::RX_NGINX_X_REQUEST_START = T.let(T.unsafe(nil), Regexp)

# source://rack-timeout//lib/rack/timeout/rails.rb#3
class Rack::Timeout::Railtie < ::Rails::Railtie; end

# source://rack-timeout//lib/rack/timeout/core.rb#27
class Rack::Timeout::RequestDetails < ::Struct
  # Returns the value of attribute id
  #
  # @return [Object] the current value of id
  def id; end

  # Sets the attribute id
  #
  # @param value [Object] the value to set the attribute id to.
  # @return [Object] the newly set value
  def id=(_); end

  # helper method used for formatting values in milliseconds
  #
  # source://rack-timeout//lib/rack/timeout/core.rb#35
  def ms(k); end

  # Returns the value of attribute service
  #
  # @return [Object] the current value of service
  def service; end

  # Sets the attribute service
  #
  # @param value [Object] the value to set the attribute service to.
  # @return [Object] the newly set value
  def service=(_); end

  # Returns the value of attribute state
  #
  # @return [Object] the current value of state
  def state; end

  # Sets the attribute state
  #
  # @param value [Object] the value to set the attribute state to.
  # @return [Object] the newly set value
  def state=(_); end

  # Returns the value of attribute term
  #
  # @return [Object] the current value of term
  def term; end

  # Sets the attribute term
  #
  # @param value [Object] the value to set the attribute term to.
  # @return [Object] the newly set value
  def term=(_); end

  # Returns the value of attribute timeout
  #
  # @return [Object] the current value of timeout
  def timeout; end

  # Sets the attribute timeout
  #
  # @param value [Object] the value to set the attribute timeout to.
  # @return [Object] the newly set value
  def timeout=(_); end

  # Returns the value of attribute wait
  #
  # @return [Object] the current value of wait
  def wait; end

  # Sets the attribute wait
  #
  # @param value [Object] the value to set the attribute wait to.
  # @return [Object] the newly set value
  def wait=(_); end

  class << self
    def [](*_arg0); end
    def inspect; end
    def keyword_init?; end
    def members; end
    def new(*_arg0); end
  end
end

# raised when a request is dropped without being given a chance to run (because too old)
#
# source://rack-timeout//lib/rack/timeout/core.rb#21
class Rack::Timeout::RequestExpiryError < ::Rack::Timeout::Error; end

# raised when a request has run for too long
#
# source://rack-timeout//lib/rack/timeout/core.rb#22
class Rack::Timeout::RequestTimeoutError < ::Rack::Timeout::Error; end

# This is first raised to help prevent an application from inadvertently catching the above. It's then caught by rack-timeout and replaced with RequestTimeoutError to bubble up to wrapping middlewares and the web server
#
# source://rack-timeout//lib/rack/timeout/core.rb#23
class Rack::Timeout::RequestTimeoutException < ::Exception
  include ::Rack::Timeout::ExceptionWithEnv
end

# Runs code at a later time
#
# Basic usage:
#
#     Scheduler.run_in(5) { do_stuff }  # <- calls do_stuff 5 seconds from now
#
# Scheduled events run in sequence in a separate thread, the main thread continues on.
# That means you may need to #join the scheduler if the main thread is only waiting on scheduled events to run.
#
#     Scheduler.join
#
# Basic usage is through a singleton instance, its methods are available as class methods, as shown above.
# One could also instantiate separate instances which would get you separate run threads, but generally there's no point in it.
#
# source://rack-timeout//lib/rack/timeout/support/scheduler.rb#18
class Rack::Timeout::Scheduler
  include ::Rack::Timeout::MonotonicTime

  # @return [Scheduler] a new instance of Scheduler
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#58
  def initialize; end

  # reschedules an event by the given number of seconds. can be negative to run sooner.
  # returns nil and does nothing if the event is not already in the queue (might've run already), otherwise updates the event time in-place; returns the updated event.
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#123
  def delay(event, secs); end

  # waits on the runner thread to finish
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#109
  def join; end

  # schedules a block to run every x seconds; returns the created event object
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#138
  def run_every(seconds, &block); end

  # schedules a block to run in the given number of seconds; returns the created event object
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#133
  def run_in(secs, &block); end

  # adds a RunEvent struct to the run schedule
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#115
  def schedule(event); end

  private

  # the actual runner thread loop
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#78
  def run_loop!; end

  # returns the runner thread, creating it if needed
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#69
  def runner; end

  class << self
    # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#152
    def delay(*a, &b); end

    # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#152
    def join(*a, &b); end

    # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#152
    def run_every(*a, &b); end

    # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#152
    def run_in(*a, &b); end

    # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#152
    def schedule(*a, &b); end

    # accessor to the singleton instance
    #
    # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#146
    def singleton; end
  end
end

# how long the runner thread is allowed to live doing nothing
#
# source://rack-timeout//lib/rack/timeout/support/scheduler.rb#19
Rack::Timeout::Scheduler::MAX_IDLE_SECS = T.let(T.unsafe(nil), Integer)

# source://rack-timeout//lib/rack/timeout/support/scheduler.rb#43
class Rack::Timeout::Scheduler::RepeatEvent < ::Rack::Timeout::Scheduler::RunEvent
  # @return [RepeatEvent] a new instance of RepeatEvent
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#44
  def initialize(monotime, proc, every); end

  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#51
  def run!; end
end

# stores a proc to run later, and the time it should run at
#
# source://rack-timeout//lib/rack/timeout/support/scheduler.rb#23
class Rack::Timeout::Scheduler::RunEvent < ::Struct
  # @return [RunEvent] a new instance of RunEvent
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#24
  def initialize(*args); end

  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#29
  def cancel!; end

  # @return [Boolean]
  #
  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#33
  def cancelled?; end

  # source://rack-timeout//lib/rack/timeout/support/scheduler.rb#37
  def run!; end
end

# source://rack-timeout//lib/rack/timeout/support/timeout.rb#4
class Rack::Timeout::Scheduler::Timeout
  # initializes a timeout object with an optional block to handle the timeout differently. the block is passed the thread that's gone overtime.
  #
  # @return [Timeout] a new instance of Timeout
  #
  # source://rack-timeout//lib/rack/timeout/support/timeout.rb#9
  def initialize(&on_timeout); end

  # takes number of seconds to wait before timing out, and code block subject to time out
  #
  # source://rack-timeout//lib/rack/timeout/support/timeout.rb#15
  def timeout(secs, &block); end

  class << self
    # timeout method on singleton instance for when a custom on_timeout is not required
    #
    # source://rack-timeout//lib/rack/timeout/support/timeout.rb#25
    def timeout(secs, &block); end
  end
end

# source://rack-timeout//lib/rack/timeout/support/timeout.rb#5
class Rack::Timeout::Scheduler::Timeout::Error < ::RuntimeError; end

# default action to take when a timeout happens
#
# source://rack-timeout//lib/rack/timeout/support/timeout.rb#6
Rack::Timeout::Scheduler::Timeout::ON_TIMEOUT = T.let(T.unsafe(nil), Proc)

# source://rack-timeout//lib/rack/timeout/logging-observer.rb#4
class Rack::Timeout::StateChangeLoggingObserver
  # @return [StateChangeLoggingObserver] a new instance of StateChangeLoggingObserver
  #
  # source://rack-timeout//lib/rack/timeout/logging-observer.rb#11
  def initialize; end

  # returns the Proc to be used as the observer callback block
  #
  # source://rack-timeout//lib/rack/timeout/logging-observer.rb#16
  def callback; end

  # Sets the attribute logger
  #
  # @param value the value to set the attribute logger to.
  #
  # source://rack-timeout//lib/rack/timeout/logging-observer.rb#29
  def logger=(_arg0); end

  private

  # generates the actual log string
  #
  # source://rack-timeout//lib/rack/timeout/logging-observer.rb#42
  def log_state_change(env); end

  # source://rack-timeout//lib/rack/timeout/logging-observer.rb#33
  def logger(env = T.unsafe(nil)); end

  class << self
    # source://rack-timeout//lib/rack/timeout/logging-observer.rb#21
    def mk_logger(device, level = T.unsafe(nil)); end
  end
end

# source://rack-timeout//lib/rack/timeout/logging-observer.rb#20
Rack::Timeout::StateChangeLoggingObserver::SIMPLE_FORMATTER = T.let(T.unsafe(nil), Proc)

# source://rack-timeout//lib/rack/timeout/logging-observer.rb#5
Rack::Timeout::StateChangeLoggingObserver::STATE_LOG_LEVEL = T.let(T.unsafe(nil), Hash)

# source://rack-timeout//lib/rack/timeout/core.rb#39
Rack::Timeout::VALID_STATES = T.let(T.unsafe(nil), Array)
