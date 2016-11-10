class FakeSamlRequest
  def service_provider
    self
  end

  def identifier
    'http://localhost:3000'
  end

  def requested_authn_context
    Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
  end

  def valid?
    true
  end
end
