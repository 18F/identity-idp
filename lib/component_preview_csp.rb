class ComponentPreviewCsp
  COMPONENT_REQUEST_PATH = /^\/components(\/|$)/

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    request = Rack::Request.new(env)

    if headers['Content-Security-Policy'].present? && request.path.match?(COMPONENT_REQUEST_PATH)
      headers['Content-Security-Policy'] = headers['Content-Security-Policy'].
        split(';').
        map(&:strip).
        map do |directive|
          directive.
            sub(/^script-src .+/, "script-src * 'unsafe-eval' 'unsafe-inline'").
            sub(/^style-src .+/, "style-src * 'unsafe-inline'")
        end.
        join(';')
    end

    [status, headers, body]
  end
end
