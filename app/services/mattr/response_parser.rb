# frozen_string_literal: true

module Mattr
  class ResponseParser < Mdoc::ResponseParser
    def initialize(credential)
      @credential = credential
      super(credential&.dig('claims'))
    end

    def parse
      unless verified?
        @errors << 'credential not verified'
        return false
      end
      super
    end

    private

    def verified?
      @credential&.dig('verificationResult', 'verified') == true
    end

    def extract_value(claims_hash, key)
      claims_hash&.dig(key, 'value')
    end
  end
end
