require 'builder'
module SamlIdp
  class SignedInfoBuilder
    include Algorithmable

    SIGNATURE_METHODS = {
      "sha1" => "http://www.w3.org/2000/09/xmldsig#rsa-sha1",
      "sha224" => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha224",
      "sha256" => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
      "sha384" => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha384",
      "sha512" => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha512",
    }
    DIGEST_METHODS = {
      "sha1" => "http://www.w3.org/2000/09/xmldsig#sha1",
      "sha224" => "http://www.w3.org/2001/04/xmldsig-more#sha224",
      "sha256" => "http://www.w3.org/2001/04/xmlenc#sha256",
      "sha384" => "http://www.w3.org/2001/04/xmldsig-more#sha384",
      "sha512" => "http://www.w3.org/2001/04/xmlenc#sha512",
    }


    attr_accessor :reference_id
    attr_accessor :digest_value
    attr_accessor :raw_algorithm
    attr_accessor :cloudhsm_key_label

    def initialize(
      reference_id, digest_value, raw_algorithm,
      secret_key:, cloudhsm_key_label:
    )
      self.reference_id = reference_id
      self.digest_value = digest_value
      self.raw_algorithm = raw_algorithm
      @secret_key = secret_key
      self.cloudhsm_key_label = cloudhsm_key_label
    end

    def raw
      builder = Builder::XmlMarkup.new
      builder.tag! "ds:SignedInfo", "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#" do |signed_info|
        signed_info.tag!("ds:CanonicalizationMethod", Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") {}
        signed_info.tag!("ds:SignatureMethod", Algorithm: signature_method ) {}
        signed_info.tag! "ds:Reference", URI: reference_string do |reference|
          reference.tag! "ds:Transforms" do |transforms|
            transforms.tag!("ds:Transform", Algorithm: "http://www.w3.org/2000/09/xmldsig#enveloped-signature") {}
            transforms.tag!("ds:Transform", Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") {}
          end
          reference.tag!("ds:DigestMethod", Algorithm: digest_method) {}
          reference.tag! "ds:DigestValue", digest_value
        end
      end
    end

    def signed
      encoded.gsub(/\n/, "")
    end

    def digest_method
      DIGEST_METHODS.fetch(clean_algorithm_name, DIGEST_METHODS["sha1"])
    end
    private :digest_method

    def signature_method
      SIGNATURE_METHODS.fetch(clean_algorithm_name, SIGNATURE_METHODS["sha1"])
    end
    private :signature_method

    def clean_algorithm_name
      algorithm_name.to_s.downcase
    end
    private :clean_algorithm_name

    def encoded
      config = SamlIdp.config
      if config.cloudhsm_enabled && cloudhsm_key_label.present?
        cloudhsm_encoded(config)
      else
        key = OpenSSL::PKey::RSA.new(@secret_key, password)
        Base64.strict_encode64(key.sign(algorithm.new, raw))
      end
    end
    private :encoded

    def cloudhsm_encoded(config)
      config.pkcs11.active_slots.first.open do |session|
        session.login(:USER, config.cloudhsm_pin)
        begin
          key = session.find_objects(LABEL: cloudhsm_key_label).first
          raise "cloudhsm key not found for label: #{cloudhsm_key_label}" unless key
          Base64.strict_encode64(session.sign(:SHA256_RSA_PKCS, key, raw))
        ensure
          session.logout
        end
      end
    end
    private :cloudhsm_encoded

    def using_config_secret_key?
      @secret_key == SamlIdp.config.secret_key
    end

    def password
      SamlIdp.config.password if using_config_secret_key?
    end

    def reference_string
      "#_#{reference_id}"
    end
    private :reference_string
  end
end
