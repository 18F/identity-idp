class CanonicalHost
  HTML_TEMPLATE = <<-HTML.gsub(/^\s+/, '')
    <!DOCTYPE html>
    <html lang="en-US">
      <head><title>301 Moved Permanently</title></head>
      <body>
        <h1>Moved Permanently</h1>
        <p>The document has moved <a href="%s">here</a>.</p>
      </body>
    </html>
  HTML

  def initialize(app)
    @app = app
    @canonical_host_app = build_canonical_host_app
  end

  def call(env)
    request = Rack::Request.new(env)
    if %w[http https].include?(request.scheme)
      canonical_host_app.call(env)
    else
      app.call(env)
    end
  rescue Addressable::URI::InvalidURIError
    redirect(request)
  end

  private

  attr_reader :app, :canonical_host_app

  def redirect(request)
    new_uri = build_new_uri(request)
    [
      301,
      { 'Content-Type' => 'text/plain',
        'Location' => new_uri,
        'Cache-control' => 'no-cache' },
      [HTML_TEMPLATE % new_uri],
    ]
  end

  # :reek:FeatureEnvy
  def build_new_uri(request)
    URI::HTTP.build(
      scheme: request.scheme,
      host: domain_name,
      port: request.port,
      path: request.path
    ).to_s
  end

  def build_canonical_host_app
    if Figaro.env.domain_name.present?
      Rack::CanonicalHost.new(app, domain_name, ignore: ignored_domain_names)
    else
      app
    end
  end

  def domain_name
    @domain_name ||= begin
      full_domain_name = Figaro.env.domain_name
      full_domain_name.split(/:/, 2).first # for 'localhost:3000'
    end
  end

  def ignored_domain_names
    allowed_domain_names = Figaro.env.allowed_domain_names
    if allowed_domain_names.present?
      JSON.parse(allowed_domain_names)
    else
      []
    end
  end
end
