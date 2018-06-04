class CloudhsmJwt
  def self.encode(jwt_payload)
    key, algorithm = if FeatureManagement.use_cloudhsm?
                       [Figaro.env.cloudhsm_saml_key_label, rs256_algorithm]
                     else
                       [RequestKeyManager.private_key, 'RS256']
                     end
    JWT.encode(jwt_payload, key, algorithm)
  end

  def self.rs256_algorithm
    lambda do |input, key|
      raise "Not a CloudHSM key label: #{key.inspect}" unless key.class == String
      sign(SamlIdp.config, key, input)
    end
  end
  private_class_method :rs256_algorithm

  def self.sign(config, key, input)
    config.pkcs11.active_slots.first.open do |session|
      session.login(:USER, config.cloudhsm_pin)
      begin
        pkcs11_key = session.find_objects(LABEL: key).first
        raise "CloudHSM key not found for label: #{key}" unless pkcs11_key
        session.sign(:SHA256_RSA_PKCS, pkcs11_key, input)
      ensure
        session.logout
      end
    end
  end
  private_class_method :sign
end
