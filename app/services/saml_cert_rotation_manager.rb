class SamlCertRotationManager
  def self.new_certificate
    filepath = Rails.root.join(
      'certs',
      Figaro.env.saml_secret_rotation_certificate
    )
    File.read(filepath)
  end

  def self.new_secret_key
    env = Figaro.env
    return env.saml_secret_rotation_cloudhsm_saml_key_label if FeatureManagement.use_cloudhsm?
    filepath = Rails.root.join(
      'keys',
      env.saml_secret_rotation_secret_key
    )
    load_secret_key_at_path(filepath).to_pem
  end

  def self.rotation_path_suffix
    Figaro.env.saml_secret_rotation_path_suffix
  end

  def self.use_new_secrets_for_request?(request)
    return false unless FeatureManagement.enable_saml_cert_rotation?
    return false unless request.path =~ /#{rotation_path_suffix}$/
    true
  end

  def self.load_secret_key_at_path(filepath)
    OpenSSL::PKey::RSA.new(
      File.read(filepath),
      Figaro.env.saml_secret_rotation_secret_key_password
    )
  end
  private_class_method :load_secret_key_at_path
end
