class SamlIdpEncryptionConfigurator
  def self.configure(config)
    if FeatureManagement.use_cloudhsm?
      env = Figaro.env
      config.secret_key = env.cloudhsm_saml_key_label
      config.cloudhsm_enabled = true
      config.cloudhsm_pin = env.cloudhsm_pin
      config.pkcs11 = PKCS11.open(env.pkcs11_lib) unless Rails.env.test?
    else
      config.secret_key = RequestKeyManager.private_key.to_pem
    end
  end
end
