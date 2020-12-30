class SecureHeadersWhitelister
  def self.extract_domain(url)
    url.split('//')[1].split('/')[0]
  end

  def self.csp_with_sp_redirect_uris(action_url_domain, sp_redirect_uris)
    csp_uris = ["'self'", action_url_domain]

    csp_uris |= sp_redirect_uris.compact if sp_redirect_uris.present?

    csp_uris
  end

  def self.append_script_src(sources)
    script_srcs = script_src + sources
    script_srcs.uniq!

    script_srcs
  end

  def self.script_src
    if !Rails.env.production?
      [:self, :unsafe_eval, :unsafe_inline]
    else
      [
        :self,
        '*.newrelic.com',
        '*.nr-data.net',
        'dap.digitalgov.gov',
        '*.google-analytics.com',
        'www.google.com',
        'www.gstatic.com',
        AppConfig.env.asset_host
      ]
    end
  end

  def self.append_connect_src(sources)
    connect_srcs = connect_src + sources
    connect_srcs.uniq!

    connect_srcs
  end

  def self.connect_src
    connect_src = [:self, '*.newrelic.com', '*.nr-data.net', '*.google-analytics.com',
               'services.assureid.net']
    connect_src += %w[ws://localhost:3035 http://localhost:3035] if Rails.env.development?

    connect_src
  end
end
