# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `rack-attack` gem.
# Please instead update this file by running `bin/tapioca gem rack-attack`.


# Rack::Attack::Request is the same as ::Rack::Request by default.
#
# This is a safe place to add custom helper methods to the request object
# through monkey patching:
#
#   class Rack::Attack::Request < ::Rack::Request
#     def localhost?
#       ip == "127.0.0.1"
#     end
#   end
#
#   Rack::Attack.safelist("localhost") {|req| req.localhost? }
#
# source://rack-attack//lib/rack/attack/cache.rb#3
module Rack
  class << self
    # source://rack/3.0.11/lib/rack/version.rb#31
    def release; end

    # source://rack/3.0.11/lib/rack/version.rb#23
    def version; end
  end
end

# source://rack-attack//lib/rack/attack/cache.rb#4
class Rack::Attack
  # @return [Attack] a new instance of Attack
  #
  # source://rack-attack//lib/rack/attack.rb#99
  def initialize(app); end

  # source://rack-attack//lib/rack/attack.rb#104
  def call(env); end

  # Returns the value of attribute configuration.
  #
  # source://rack-attack//lib/rack/attack.rb#97
  def configuration; end

  class << self
    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklist(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklist_ip(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklisted_responder(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklisted_responder=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklisted_response(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklisted_response=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def blocklists(*args, **_arg1, &block); end

    # source://rack-attack//lib/rack/attack.rb#49
    def cache; end

    # source://rack-attack//lib/rack/attack.rb#53
    def clear!; end

    # source://forwardable/1.3.3/forwardable.rb#231
    def clear_configuration(*args, **_arg1, &block); end

    # Returns the value of attribute configuration.
    #
    # source://rack-attack//lib/rack/attack.rb#37
    def configuration; end

    # Returns the value of attribute enabled.
    #
    # source://rack-attack//lib/rack/attack.rb#36
    def enabled; end

    # Sets the attribute enabled
    #
    # @param value the value to set the attribute enabled to.
    #
    # source://rack-attack//lib/rack/attack.rb#36
    def enabled=(_arg0); end

    # source://rack-attack//lib/rack/attack.rb#39
    def instrument(request); end

    # Returns the value of attribute notifier.
    #
    # source://rack-attack//lib/rack/attack.rb#36
    def notifier; end

    # Sets the attribute notifier
    #
    # @param value the value to set the attribute notifier to.
    #
    # source://rack-attack//lib/rack/attack.rb#36
    def notifier=(_arg0); end

    # source://rack-attack//lib/rack/attack.rb#58
    def reset!; end

    # source://forwardable/1.3.3/forwardable.rb#231
    def safelist(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def safelist_ip(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def safelists(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttle(*args, **_arg1, &block); end

    # Returns the value of attribute throttle_discriminator_normalizer.
    #
    # source://rack-attack//lib/rack/attack.rb#36
    def throttle_discriminator_normalizer; end

    # Sets the attribute throttle_discriminator_normalizer
    #
    # @param value the value to set the attribute throttle_discriminator_normalizer to.
    #
    # source://rack-attack//lib/rack/attack.rb#36
    def throttle_discriminator_normalizer=(_arg0); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttled_responder(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttled_responder=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttled_response(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttled_response=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttled_response_retry_after_header(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttled_response_retry_after_header=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def throttles(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def track(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def tracks(*args, **_arg1, &block); end
  end
end

# source://rack-attack//lib/rack/attack/allow2ban.rb#5
class Rack::Attack::Allow2Ban < ::Rack::Attack::Fail2Ban
  class << self
    protected

    # everything is the same here except we only return true
    # (blocking the request) if they have tripped the limit.
    #
    # source://rack-attack//lib/rack/attack/allow2ban.rb#15
    def fail!(discriminator, bantime, findtime, maxretry); end

    # source://rack-attack//lib/rack/attack/allow2ban.rb#9
    def key_prefix; end
  end
end

# source://rack-attack//lib/rack/attack/base_proxy.rb#7
class Rack::Attack::BaseProxy < ::SimpleDelegator
  class << self
    # @raise [NotImplementedError]
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/base_proxy.rb#22
    def handle?(_store); end

    # @private
    #
    # source://rack-attack//lib/rack/attack/base_proxy.rb#13
    def inherited(klass); end

    # source://rack-attack//lib/rack/attack/base_proxy.rb#18
    def lookup(store); end

    # source://rack-attack//lib/rack/attack/base_proxy.rb#9
    def proxies; end
  end
end

# source://rack-attack//lib/rack/attack/blocklist.rb#5
class Rack::Attack::Blocklist < ::Rack::Attack::Check
  # @return [Blocklist] a new instance of Blocklist
  #
  # source://rack-attack//lib/rack/attack/blocklist.rb#6
  def initialize(name = T.unsafe(nil), &block); end
end

# source://rack-attack//lib/rack/attack/cache.rb#5
class Rack::Attack::Cache
  # @return [Cache] a new instance of Cache
  #
  # source://rack-attack//lib/rack/attack/cache.rb#15
  def initialize(store: T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/cache.rb#31
  def count(unprefixed_key, period); end

  # source://rack-attack//lib/rack/attack/cache.rb#52
  def delete(unprefixed_key); end

  # Returns the value of attribute last_epoch_time.
  #
  # source://rack-attack//lib/rack/attack/cache.rb#7
  def last_epoch_time; end

  # Returns the value of attribute prefix.
  #
  # source://rack-attack//lib/rack/attack/cache.rb#6
  def prefix; end

  # Sets the attribute prefix
  #
  # @param value the value to set the attribute prefix to.
  #
  # source://rack-attack//lib/rack/attack/cache.rb#6
  def prefix=(_arg0); end

  # source://rack-attack//lib/rack/attack/cache.rb#36
  def read(unprefixed_key); end

  # source://rack-attack//lib/rack/attack/cache.rb#56
  def reset!; end

  # source://rack-attack//lib/rack/attack/cache.rb#47
  def reset_count(unprefixed_key, period); end

  # Returns the value of attribute store.
  #
  # source://rack-attack//lib/rack/attack/cache.rb#20
  def store; end

  # source://rack-attack//lib/rack/attack/cache.rb#22
  def store=(store); end

  # source://rack-attack//lib/rack/attack/cache.rb#43
  def write(unprefixed_key, value, expires_in); end

  private

  # source://rack-attack//lib/rack/attack/cache.rb#76
  def do_count(key, expires_in); end

  # source://rack-attack//lib/rack/attack/cache.rb#97
  def enforce_store_method_presence!(method_name); end

  # source://rack-attack//lib/rack/attack/cache.rb#91
  def enforce_store_presence!; end

  # source://rack-attack//lib/rack/attack/cache.rb#69
  def key_and_expiry(unprefixed_key, period); end

  class << self
    # source://rack-attack//lib/rack/attack/cache.rb#9
    def default_store; end
  end
end

# source://rack-attack//lib/rack/attack/check.rb#5
class Rack::Attack::Check
  # @return [Check] a new instance of Check
  #
  # source://rack-attack//lib/rack/attack/check.rb#8
  def initialize(name, options = T.unsafe(nil), &block); end

  # Returns the value of attribute block.
  #
  # source://rack-attack//lib/rack/attack/check.rb#6
  def block; end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/check.rb#14
  def matched_by?(request); end

  # Returns the value of attribute name.
  #
  # source://rack-attack//lib/rack/attack/check.rb#6
  def name; end

  # Returns the value of attribute type.
  #
  # source://rack-attack//lib/rack/attack/check.rb#6
  def type; end
end

# source://rack-attack//lib/rack/attack/configuration.rb#7
class Rack::Attack::Configuration
  # @return [Configuration] a new instance of Configuration
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#39
  def initialize; end

  # Returns the value of attribute anonymous_blocklists.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#22
  def anonymous_blocklists; end

  # Returns the value of attribute anonymous_safelists.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#22
  def anonymous_safelists; end

  # source://rack-attack//lib/rack/attack/configuration.rb#53
  def blocklist(name = T.unsafe(nil), &block); end

  # source://rack-attack//lib/rack/attack/configuration.rb#63
  def blocklist_ip(ip_address); end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#88
  def blocklisted?(request); end

  # Returns the value of attribute blocklisted_responder.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#23
  def blocklisted_responder; end

  # Sets the attribute blocklisted_responder
  #
  # @param value the value to set the attribute blocklisted_responder to.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#23
  def blocklisted_responder=(_arg0); end

  # Keeping these for backwards compatibility
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#25
  def blocklisted_response; end

  # source://rack-attack//lib/rack/attack/configuration.rb#27
  def blocklisted_response=(responder); end

  # Returns the value of attribute blocklists.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#22
  def blocklists; end

  # source://rack-attack//lib/rack/attack/configuration.rb#105
  def clear_configuration; end

  # source://rack-attack//lib/rack/attack/configuration.rb#43
  def safelist(name = T.unsafe(nil), &block); end

  # source://rack-attack//lib/rack/attack/configuration.rb#69
  def safelist_ip(ip_address); end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#83
  def safelisted?(request); end

  # Returns the value of attribute safelists.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#22
  def safelists; end

  # source://rack-attack//lib/rack/attack/configuration.rb#75
  def throttle(name, options, &block); end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#93
  def throttled?(request); end

  # Returns the value of attribute throttled_responder.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#23
  def throttled_responder; end

  # Sets the attribute throttled_responder
  #
  # @param value the value to set the attribute throttled_responder to.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#23
  def throttled_responder=(_arg0); end

  # Keeping these for backwards compatibility
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#25
  def throttled_response; end

  # source://rack-attack//lib/rack/attack/configuration.rb#33
  def throttled_response=(responder); end

  # Returns the value of attribute throttled_response_retry_after_header.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#23
  def throttled_response_retry_after_header; end

  # Sets the attribute throttled_response_retry_after_header
  #
  # @param value the value to set the attribute throttled_response_retry_after_header to.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#23
  def throttled_response_retry_after_header=(_arg0); end

  # Returns the value of attribute throttles.
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#22
  def throttles; end

  # source://rack-attack//lib/rack/attack/configuration.rb#79
  def track(name, options = T.unsafe(nil), &block); end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/configuration.rb#99
  def tracked?(request); end

  private

  # source://rack-attack//lib/rack/attack/configuration.rb#111
  def set_defaults; end
end

# source://rack-attack//lib/rack/attack/configuration.rb#8
Rack::Attack::Configuration::DEFAULT_BLOCKLISTED_RESPONDER = T.let(T.unsafe(nil), Proc)

# source://rack-attack//lib/rack/attack/configuration.rb#10
Rack::Attack::Configuration::DEFAULT_THROTTLED_RESPONDER = T.let(T.unsafe(nil), Proc)

# source://rack-attack//lib/rack/attack.rb#19
class Rack::Attack::Error < ::StandardError; end

# source://rack-attack//lib/rack/attack/fail2ban.rb#5
class Rack::Attack::Fail2Ban
  class << self
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/fail2ban.rb#27
    def banned?(discriminator); end

    # source://rack-attack//lib/rack/attack/fail2ban.rb#7
    def filter(discriminator, options); end

    # source://rack-attack//lib/rack/attack/fail2ban.rb#20
    def reset(discriminator, options); end

    protected

    # source://rack-attack//lib/rack/attack/fail2ban.rb#37
    def fail!(discriminator, bantime, findtime, maxretry); end

    # source://rack-attack//lib/rack/attack/fail2ban.rb#33
    def key_prefix; end

    private

    # source://rack-attack//lib/rack/attack/fail2ban.rb#48
    def ban!(discriminator, bantime); end

    # source://rack-attack//lib/rack/attack/fail2ban.rb#52
    def cache; end
  end
end

# When using Rack::Attack with a Rails app, developers expect the request path
# to be normalized. In particular, trailing slashes are stripped.
# (See
# https://github.com/rails/rails/blob/f8edd20/actionpack/lib/action_dispatch/journey/router/utils.rb#L5-L22
# for implementation.)
#
# Look for an ActionDispatch utility class that Rails folks would expect
# to normalize request paths. If unavailable, use a fallback class that
# doesn't normalize the path (as a non-Rails rack app developer expects).
#
# source://rack-attack//lib/rack/attack/path_normalizer.rb#15
module Rack::Attack::FallbackPathNormalizer
  class << self
    # source://rack-attack//lib/rack/attack/path_normalizer.rb#16
    def normalize_path(path); end
  end
end

# source://rack-attack//lib/rack/attack.rb#25
class Rack::Attack::IncompatibleStoreError < ::Rack::Attack::Error; end

# source://rack-attack//lib/rack/attack.rb#21
class Rack::Attack::MisconfiguredStoreError < ::Rack::Attack::Error; end

# source://rack-attack//lib/rack/attack.rb#23
class Rack::Attack::MissingStoreError < ::Rack::Attack::Error; end

# source://rack-attack//lib/rack/attack/path_normalizer.rb#21
Rack::Attack::PathNormalizer = ActionDispatch::Journey::Router::Utils

# source://rack-attack//lib/rack/attack/railtie.rb#11
class Rack::Attack::Railtie < ::Rails::Railtie; end

# source://rack-attack//lib/rack/attack/request.rb#18
class Rack::Attack::Request < ::Rack::Request; end

# source://rack-attack//lib/rack/attack/safelist.rb#5
class Rack::Attack::Safelist < ::Rack::Attack::Check
  # @return [Safelist] a new instance of Safelist
  #
  # source://rack-attack//lib/rack/attack/safelist.rb#6
  def initialize(name = T.unsafe(nil), &block); end
end

# source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#7
module Rack::Attack::StoreProxy; end

# source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#8
class Rack::Attack::StoreProxy::DalliProxy < ::Rack::Attack::BaseProxy
  # @return [DalliProxy] a new instance of DalliProxy
  #
  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#21
  def initialize(client); end

  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#50
  def delete(key); end

  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#42
  def increment(key, amount, options = T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#26
  def read(key); end

  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#34
  def write(key, value, options = T.unsafe(nil)); end

  private

  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#70
  def rescuing; end

  # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#60
  def stub_with_if_missing; end

  class << self
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/store_proxy/dalli_proxy.rb#9
    def handle?(store); end
  end
end

# source://rack-attack//lib/rack/attack/store_proxy/mem_cache_store_proxy.rb#8
class Rack::Attack::StoreProxy::MemCacheStoreProxy < ::Rack::Attack::BaseProxy
  # source://rack-attack//lib/rack/attack/store_proxy/mem_cache_store_proxy.rb#15
  def read(name, options = T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/store_proxy/mem_cache_store_proxy.rb#19
  def write(name, value, options = T.unsafe(nil)); end

  class << self
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/store_proxy/mem_cache_store_proxy.rb#9
    def handle?(store); end
  end
end

# source://rack-attack//lib/rack/attack/store_proxy/redis_cache_store_proxy.rb#8
class Rack::Attack::StoreProxy::RedisCacheStoreProxy < ::Rack::Attack::BaseProxy
  # source://rack-attack//lib/rack/attack/store_proxy/redis_cache_store_proxy.rb#29
  def read(name, options = T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_cache_store_proxy.rb#33
  def write(name, value, options = T.unsafe(nil)); end

  class << self
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/store_proxy/redis_cache_store_proxy.rb#9
    def handle?(store); end
  end
end

# source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#8
class Rack::Attack::StoreProxy::RedisProxy < ::Rack::Attack::BaseProxy
  # @return [RedisProxy] a new instance of RedisProxy
  #
  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#9
  def initialize(*args); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#42
  def delete(key, _options = T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#46
  def delete_matched(matcher, _options = T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#33
  def increment(key, amount, options = T.unsafe(nil)); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#21
  def read(key); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#25
  def write(key, value, options = T.unsafe(nil)); end

  private

  # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#61
  def rescuing; end

  class << self
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/store_proxy/redis_proxy.rb#17
    def handle?(store); end
  end
end

# source://rack-attack//lib/rack/attack/store_proxy/redis_store_proxy.rb#8
class Rack::Attack::StoreProxy::RedisStoreProxy < ::Rack::Attack::StoreProxy::RedisProxy
  # source://rack-attack//lib/rack/attack/store_proxy/redis_store_proxy.rb#13
  def read(key); end

  # source://rack-attack//lib/rack/attack/store_proxy/redis_store_proxy.rb#17
  def write(key, value, options = T.unsafe(nil)); end

  class << self
    # @return [Boolean]
    #
    # source://rack-attack//lib/rack/attack/store_proxy/redis_store_proxy.rb#9
    def handle?(store); end
  end
end

# source://rack-attack//lib/rack/attack/throttle.rb#5
class Rack::Attack::Throttle
  # @return [Throttle] a new instance of Throttle
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#10
  def initialize(name, options, &block); end

  # Returns the value of attribute block.
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#8
  def block; end

  # source://rack-attack//lib/rack/attack/throttle.rb#21
  def cache; end

  # Returns the value of attribute limit.
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#8
  def limit; end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#25
  def matched_by?(request); end

  # Returns the value of attribute name.
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#8
  def name; end

  # Returns the value of attribute period.
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#8
  def period; end

  # Returns the value of attribute type.
  #
  # source://rack-attack//lib/rack/attack/throttle.rb#8
  def type; end

  private

  # source://rack-attack//lib/rack/attack/throttle.rb#73
  def annotate_request_with_matched_data(request, data); end

  # source://rack-attack//lib/rack/attack/throttle.rb#69
  def annotate_request_with_throttle_data(request, data); end

  # source://rack-attack//lib/rack/attack/throttle.rb#53
  def discriminator_for(request); end

  # source://rack-attack//lib/rack/attack/throttle.rb#65
  def limit_for(request); end

  # source://rack-attack//lib/rack/attack/throttle.rb#61
  def period_for(request); end
end

# source://rack-attack//lib/rack/attack/throttle.rb#6
Rack::Attack::Throttle::MANDATORY_OPTIONS = T.let(T.unsafe(nil), Array)

# source://rack-attack//lib/rack/attack/track.rb#5
class Rack::Attack::Track
  # @return [Track] a new instance of Track
  #
  # source://rack-attack//lib/rack/attack/track.rb#8
  def initialize(name, options = T.unsafe(nil), &block); end

  # Returns the value of attribute filter.
  #
  # source://rack-attack//lib/rack/attack/track.rb#6
  def filter; end

  # @return [Boolean]
  #
  # source://rack-attack//lib/rack/attack/track.rb#19
  def matched_by?(request); end
end
