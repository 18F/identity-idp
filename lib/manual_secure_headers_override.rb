# A tiny middleware that calls a block on each *successful*
# request. Intended so that we can override SecureHeaders
# using Middleware only, for example for overriding SecureHeaders
# directive on static files
class ManualSecureHeadersOverride
  # @yieldparam [Rack::Request] request
  def initialize(app, &block)
    @app = app
    @block = block
  end

  def call(env)
    status, headers, body = @app.call(env)

    @block.call(Rack::Request.new(env)) if status == 200

    [status, headers, body]
  end
end
