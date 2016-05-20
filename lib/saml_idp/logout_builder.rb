require 'builder'
module SamlIdp
  class LogoutBuilder
    include Signable

    # this is an abstract base class.
    def signature_opts
      raise "#{self.class} must implement signature_opts method"
    end

    def build
      raise "#{self.class} must implement build method"
    end

    def reference_id
      UUID.generate
    end

    def digest
      algorithm.hexdigest raw
    end

    def algorithm
      signature_opts[:algorithm] || OpenSSL::Digest::SHA256
    end

    def encoded
      @encoded ||= encode
    end 

    def raw 
      build
    end 

    def encode
      Base64.strict_encode64(raw)
    end 
    private :encode

    def response_id_string
      "_#{response_id}"
    end 
    private :response_id_string

    def now_iso
      Time.now.utc.iso8601
    end
    private :now_iso
  end
end
