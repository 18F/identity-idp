module Encryption
  module Encodable
    extend ActiveSupport::Concern

    private

    def valid_base64_encoding?(text)
      Base64.strict_decode64(text)
    rescue StandardError
      false
    end

    def encode(text)
      Base64.strict_encode64(text)
    end

    def decode(text)
      Base64.strict_decode64(text)
    end
  end
end
