# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `rack-cors` gem.
# Please instead update this file by running `bin/tapioca gem rack-cors`.


# source://rack-cors//lib/rack/cors/resources/cors_misconfiguration_error.rb#3
module Rack
  class << self
    # source://rack/3.0.11/lib/rack/version.rb#31
    def release; end

    # source://rack/3.0.11/lib/rack/version.rb#23
    def version; end
  end
end

# source://rack-cors//lib/rack/cors/resources/cors_misconfiguration_error.rb#4
class Rack::Cors
  # @return [Cors] a new instance of Cors
  #
  # source://rack-cors//lib/rack/cors.rb#29
  def initialize(app, opts = T.unsafe(nil), &block); end

  # source://rack-cors//lib/rack/cors.rb#56
  def allow(&block); end

  # source://rack-cors//lib/rack/cors.rb#66
  def call(env); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors.rb#52
  def debug?; end

  protected

  # source://rack-cors//lib/rack/cors.rb#167
  def all_resources; end

  # source://rack-cors//lib/rack/cors.rb#134
  def debug(env, message = T.unsafe(nil), &block); end

  # source://rack-cors//lib/rack/cors.rb#155
  def evaluate_path(env); end

  # source://rack-cors//lib/rack/cors.rb#204
  def match_resource(path, env); end

  # source://rack-cors//lib/rack/cors.rb#183
  def process_cors(env, path); end

  # source://rack-cors//lib/rack/cors.rb#171
  def process_preflight(env, path); end

  # source://rack-cors//lib/rack/cors.rb#196
  def resource_for_path(path_info); end

  # source://rack-cors//lib/rack/cors.rb#138
  def select_logger(env); end
end

# source://rack-cors//lib/rack/cors.rb#27
Rack::Cors::DEFAULT_VARY_HEADERS = T.let(T.unsafe(nil), Array)

# source://rack-cors//lib/rack/cors.rb#23
Rack::Cors::ENV_KEY = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#15
Rack::Cors::HTTP_ACCESS_CONTROL_REQUEST_HEADERS = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#14
Rack::Cors::HTTP_ACCESS_CONTROL_REQUEST_METHOD = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#11
Rack::Cors::HTTP_ORIGIN = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#12
Rack::Cors::HTTP_X_ORIGIN = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#25
Rack::Cors::OPTIONS = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#17
Rack::Cors::PATH_INFO = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#21
Rack::Cors::RACK_CORS = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#20
Rack::Cors::RACK_LOGGER = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors.rb#18
Rack::Cors::REQUEST_METHOD = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/resources/cors_misconfiguration_error.rb#5
class Rack::Cors::Resource
  # @raise [CorsMisconfigurationError]
  # @return [Resource] a new instance of Resource
  #
  # source://rack-cors//lib/rack/cors/resource.rb#12
  def initialize(public_resource, path, opts = T.unsafe(nil)); end

  # Returns the value of attribute credentials.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def credentials; end

  # Sets the attribute credentials
  #
  # @param value the value to set the attribute credentials to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def credentials=(_arg0); end

  # Returns the value of attribute expose.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def expose; end

  # Sets the attribute expose
  #
  # @param value the value to set the attribute expose to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def expose=(_arg0); end

  # Returns the value of attribute headers.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def headers; end

  # Sets the attribute headers
  #
  # @param value the value to set the attribute headers to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def headers=(_arg0); end

  # Returns the value of attribute if_proc.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def if_proc; end

  # Sets the attribute if_proc
  #
  # @param value the value to set the attribute if_proc to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def if_proc=(_arg0); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/resource.rb#43
  def match?(path, env); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/resource.rb#39
  def matches_path?(path); end

  # Returns the value of attribute max_age.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def max_age; end

  # Sets the attribute max_age
  #
  # @param value the value to set the attribute max_age to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def max_age=(_arg0); end

  # Returns the value of attribute methods.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def methods; end

  # Sets the attribute methods
  #
  # @param value the value to set the attribute methods to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def methods=(_arg0); end

  # Returns the value of attribute path.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def path; end

  # Sets the attribute path
  #
  # @param value the value to set the attribute path to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def path=(_arg0); end

  # Returns the value of attribute pattern.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def pattern; end

  # Sets the attribute pattern
  #
  # @param value the value to set the attribute pattern to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def pattern=(_arg0); end

  # source://rack-cors//lib/rack/cors/resource.rb#47
  def process_preflight(env, result); end

  # source://rack-cors//lib/rack/cors/resource.rb#61
  def to_headers(env); end

  # Returns the value of attribute vary_headers.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def vary_headers; end

  # Sets the attribute vary_headers
  #
  # @param value the value to set the attribute vary_headers to.
  #
  # source://rack-cors//lib/rack/cors/resource.rb#10
  def vary_headers=(_arg0); end

  protected

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/resource.rb#90
  def allow_headers?(request_headers); end

  # source://rack-cors//lib/rack/cors/resource.rb#107
  def compile(path); end

  # source://rack-cors//lib/rack/cors/resource.rb#101
  def ensure_enum(var); end

  # source://rack-cors//lib/rack/cors/resource.rb#131
  def header_proc; end

  # source://rack-cors//lib/rack/cors/resource.rb#78
  def origin_for_response_header(origin); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/resource.rb#74
  def public_resource?; end

  # source://rack-cors//lib/rack/cors/resource.rb#84
  def to_preflight_headers(env); end
end

# All CORS routes need to accept CORS simple headers at all times
# {https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Headers}
#
# source://rack-cors//lib/rack/cors/resource.rb#8
Rack::Cors::Resource::CORS_SIMPLE_HEADERS = T.let(T.unsafe(nil), Array)

# source://rack-cors//lib/rack/cors/resources/cors_misconfiguration_error.rb#6
class Rack::Cors::Resource::CorsMisconfigurationError < ::StandardError
  # source://rack-cors//lib/rack/cors/resources/cors_misconfiguration_error.rb#7
  def message; end
end

# source://rack-cors//lib/rack/cors/resources.rb#7
class Rack::Cors::Resources
  # @return [Resources] a new instance of Resources
  #
  # source://rack-cors//lib/rack/cors/resources.rb#10
  def initialize; end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/resources.rb#39
  def allow_origin?(source, env = T.unsafe(nil)); end

  # source://rack-cors//lib/rack/cors/resources.rb#53
  def match_resource(path, env); end

  # source://rack-cors//lib/rack/cors/resources.rb#16
  def origins(*args, &blk); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/resources.rb#35
  def public_resources?; end

  # source://rack-cors//lib/rack/cors/resources.rb#31
  def resource(path, opts = T.unsafe(nil)); end

  # source://rack-cors//lib/rack/cors/resources.rb#57
  def resource_for_path(path); end

  # Returns the value of attribute resources.
  #
  # source://rack-cors//lib/rack/cors/resources.rb#8
  def resources; end
end

# source://rack-cors//lib/rack/cors/result.rb#5
class Rack::Cors::Result
  # source://rack-cors//lib/rack/cors/result.rb#51
  def append_header(headers); end

  # Returns the value of attribute hit.
  #
  # source://rack-cors//lib/rack/cors/result.rb#15
  def hit; end

  # Sets the attribute hit
  #
  # @param value the value to set the attribute hit to.
  #
  # source://rack-cors//lib/rack/cors/result.rb#15
  def hit=(_arg0); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/result.rb#17
  def hit?; end

  # source://rack-cors//lib/rack/cors/result.rb#25
  def miss(reason); end

  # Returns the value of attribute miss_reason.
  #
  # source://rack-cors//lib/rack/cors/result.rb#15
  def miss_reason; end

  # Sets the attribute miss_reason
  #
  # @param value the value to set the attribute miss_reason to.
  #
  # source://rack-cors//lib/rack/cors/result.rb#15
  def miss_reason=(_arg0); end

  # Returns the value of attribute preflight.
  #
  # source://rack-cors//lib/rack/cors/result.rb#15
  def preflight; end

  # Sets the attribute preflight
  #
  # @param value the value to set the attribute preflight to.
  #
  # source://rack-cors//lib/rack/cors/result.rb#15
  def preflight=(_arg0); end

  # @return [Boolean]
  #
  # source://rack-cors//lib/rack/cors/result.rb#21
  def preflight?; end

  class << self
    # source://rack-cors//lib/rack/cors/result.rb#30
    def hit(env); end

    # source://rack-cors//lib/rack/cors/result.rb#37
    def miss(env, reason); end

    # source://rack-cors//lib/rack/cors/result.rb#45
    def preflight(env); end
  end
end

# source://rack-cors//lib/rack/cors/result.rb#6
Rack::Cors::Result::HEADER_KEY = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/result.rb#13
Rack::Cors::Result::MISS_DENY_HEADER = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/result.rb#12
Rack::Cors::Result::MISS_DENY_METHOD = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/result.rb#11
Rack::Cors::Result::MISS_NO_METHOD = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/result.rb#8
Rack::Cors::Result::MISS_NO_ORIGIN = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/result.rb#9
Rack::Cors::Result::MISS_NO_PATH = T.let(T.unsafe(nil), String)

# source://rack-cors//lib/rack/cors/version.rb#5
Rack::Cors::VERSION = T.let(T.unsafe(nil), String)
