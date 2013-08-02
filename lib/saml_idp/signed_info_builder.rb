require 'builder'
module SamlIdp
  class SignedInfoBuilder
    attr_accessor :reference_id
    attr_accessor :digest_value
    attr_accessor :raw_algorithm

    def initialize(reference_id, digest_value, raw_algorithm)
      self.reference_id = reference_id
      self.digest_value = digest_value
      self.raw_algorithm = raw_algorithm
    end

    def raw
      build
    end

    def signed
      encoded.gsub(/\n/, "")
    end

    def secret_key
      SamlIdp.config.secret_key
    end
    private :secret_key

    def encoded
      key = OpenSSL::PKey::RSA.new(secret_key)
      Base64.encode64(key.sign(algorithm.new, raw))
    end
    private :encoded

    def build
      builder = Builder::XmlMarkup.new
      builder.tag! "ds:SignedInfo", "xmlns:ds" => "http://www.w3.org/2000/09/xmldsig#" do |signed_info|
        signed_info.tag!("ds:CanonicalizationMethod", Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") {}
        signed_info.tag!("ds:SignatureMethod", Algorithm: "http://www.w3.org/2000/09/xmldsig#rsa-#{algorithm_name}") {}
        signed_info.tag! "ds:Reference", URI: reference_string do |reference|
          reference.tag! "ds:Transforms" do |transforms|
            transforms.tag!("ds:Transform", Algorithm: "http://www.w3.org/2000/09/xmldsig#enveloped-signature") {}
            transforms.tag!("ds:Transform", Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") {}
          end
          reference.tag! "ds:DigestMethod", Algorithm: "http://www.w3.org/2000/09/xmldsig##{algorithm_name}" do
          end
          reference.tag! "ds:DigestValue", digest_value
        end
      end
    end
    private :build

    def reference_string
      "#_#{reference_id}"
    end
    private :reference_string

    def algorithm_name
      algorithm.to_s.split('::').last.downcase
    end
    private :algorithm_name

    def algorithm
      algorithm_check = raw_algorithm || SamlIdp.config.algorithm
      return algorithm_check if algorithm_check.respond_to?(:digest)
      begin
        OpenSSL::Digest.const_get(algorithm_check.to_s.upcase)
      rescue NameError
        OpenSSL::Digest::SHA1
      end
    end
    private :algorithm
  end
end
