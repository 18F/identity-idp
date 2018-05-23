class SamlAndOidcSigner
  def self.sign(algorithm, input, key)
    if ::FeatureManagement.use_cloudhsm?
      cloudhsm_sign(SamlIdp.config, input, key)
    else
      JWT::Algos::Rsa.sign JWT::Signature::ToSign.new(algorithm, input, key)
    end
  end

  def self.cloudhsm_sign(config, input, key)
    config.pkcs11.active_slots.first.open do |session|
      session.login(:USER, config.cloudhsm_pin)
      begin
        pkcs11_key = session.find_objects(LABEL: key).first
        raise "cloudhsm key not found for label: #{key}" unless pkcs11_key
        session.sign(:SHA256_RSA_PKCS, pkcs11_key, input)
      ensure
        session.logout
      end
    end
  end
  private_class_method :cloudhsm_sign
end
