class SecureHeadersAllowList
  def self.csp_with_sp_redirect_uris(action_url_domain, sp_redirect_uris)
    ["'self'"] + reduce_sp_redirect_uris_for_csp([action_url_domain, *sp_redirect_uris].compact)
  end

  ##
  # This method reduces a list of URIs into a reasonable list for the form
  # action CSP directive on a page that may redirect to a service provider.
  #
  # It is necessary to include a list of destinations because some browsers
  # enforce the form action directive on redirects. For example, an SP may have
  # a redirect uri of `https://auth.example.com/result` that then redirects to
  # `https://app.example.com/`. The redirect will violate the IDP's CSP if
  # `https://app.example.com` is not included as a form action destination.
  #
  # Validations on the service provider ensure there will be 2 types of URLs
  # this method must handle:
  # - Web URLs
  # - Native app URLs
  #
  # Web URLs need to appear in the form action directive with a scheme, host,
  # and port. As such, `https://example.com/auth/result` and
  # `https://example.com/other/path` can be reduced to `https://example.com`.
  #
  # Native app URLs are for deep links to mobile applications. They will have
  # custom schemes and simple hostnames, such as `mymobileapp://result`. These
  # URLs need to be reduced to allow the scheme, but the host information will
  # need to be removed or some browsers will reject them. In the
  # `mymobileapp://result` example the URI must be reduced to `mymobileapp://`.
  #
  def self.reduce_sp_redirect_uris_for_csp(uris)
    csp_uri_set = uris.each_with_object(Set.new) do |uri, uri_set|
      parsed_uri = URI.parse(uri)
      reduced_uri =
        if parsed_uri.scheme.match?(/\Ahttps?\z/)
          reduce_web_sp_uri(parsed_uri)
        else
          reduce_native_app_sp_uri(parsed_uri)
        end
      uri_set.add(reduced_uri)
    end
    csp_uri_set.to_a
  end

  def self.reduce_web_sp_uri(uri)
    uri.fragment = nil
    uri.query = nil
    uri.path = ''
    uri.to_s
  end

  def self.reduce_native_app_sp_uri(uri)
    "#{uri.scheme}:"
  end
end
