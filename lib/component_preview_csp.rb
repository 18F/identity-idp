require_relative './identity_config'

class ComponentPreviewCsp
  COMPONENT_REQUEST_PATH = /^\/components(\/|$)/

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    request = Rack::Request.new(env)

    if request.path.match?(COMPONENT_REQUEST_PATH)
      headers['Content-Security-Policy'] = "frame-ancestors 'self' #{IdentityConfig.store.component_previews_embed_frame_ancestors.join(' ')}"
    end

    [status, headers, body]
  end
end