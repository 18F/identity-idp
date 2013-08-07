module SamlIdp
  class Request
    def self.from_deflated_request(raw)
      zstream  = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      inflated = zstream.inflate(Base64.decode64(raw)).tap do
        zstream.finish
        zstream.close
      end
      from_string(inflated)
    end

    def self.from_string(raw)
      new Hash.from_xml(raw)
    rescue REXML::ParseException
      new
    end

    attr_accessor :hash_xml

    def initialize(hash_xml = {})
      self.hash_xml = hash_xml
    end

    def request_id
      authn_request["ID"]
    end

    def acs_url
      authn_request["AssertionConsumerServiceURL"]
    end

    def authn_request
      hash_xml.fetch("AuthnRequest") { {} }
    end
  end
end
