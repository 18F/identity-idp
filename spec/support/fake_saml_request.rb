class FakeSamlRequest
  def service_provider
    self
  end

  def identifier
    'http://localhost:3000'
  end

  def issuer
    'http://localhost:3000'
  end

  def requested_authn_context
    Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
  end

  def requested_authn_context_comparison
    'exact'
  end

  def requested_authn_contexts
    [
      Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
    ]
  end

  def requested_ial_authn_context
    Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
  end

  def requested_aal_authn_context
    Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
  end

  def valid?
    true
  end

  def name_id_format
    'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
  end

  def response_url
    'http://localhost:3000'
  end

  def request_id
    '123'
  end

  def force_authn?
    false
  end

  def authn_request?
    true
  end

  def logout_request?
    false
  end

  def logout_url
    'http://localhost:3000/saml/logout'
  end

  def options
    {
      get_params: {
        SAMLRequest: 'FakeSamlRequest',
      },
    }
  end
end
