# frozen_string_literal: true

class VersionHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    headers['X-GIT-SHA'] = IdentityConfig::GIT_SHA

    [status, headers, body]
  end
end
