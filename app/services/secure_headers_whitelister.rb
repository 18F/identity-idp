class SecureHeadersWhitelister
  def self.extract_domain(url)
    url.split('//')[1].split('/')[0]
  end

  def self.csp_with_sp_redirect_uris(action_url_domain, sp_redirect_uris)
    csp_uris = ["'self'", action_url_domain]

    csp_uris |= sp_redirect_uris.compact if sp_redirect_uris.present?

    csp_uris
  end
end
