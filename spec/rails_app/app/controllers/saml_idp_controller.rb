class SamlIdpController < SamlIdp::IdpController
  def idp_authenticate(email, _password)
    { email: }
  end

  def idp_make_saml_response(user)
    encode_response(user[:email])
  end
end
