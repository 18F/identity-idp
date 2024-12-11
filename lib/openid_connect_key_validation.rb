# frozen_string_literal: true

class OpenidConnectKeyValidation
  # @param [private_key] OpenSSL::PKey
  # @param [public_key] OpenSSL::PKey
  def self.valid?(private_key:, public_key:, data: 'abc123')
    signature = private_key.sign('SHA256', data)
    public_key.verify('SHA256', signature, data)
  end
end
