# frozen_string_literal: true

require 'base64'
require 'openssl'

##
#
# Implements HMAC PSHA1
# Ref https://tools.ietf.org/html/rfc5246#section-5
#
# p_sha1(client_secret, server_secret) = HMAC_sha1(client_secret, A(1) + server_secret) +
#                                        HMAC_sha1(client_secret, A(2) + server_secret) +
#                                        HMAC_sha1(client_secret, A(3) + server_secret) + ...
#
# where '+' indicates concatination
#
# A() is defined by
#
# A(0) = server_secret
# A(i) = HMAC_sha1(client_secret, A(i-1))
#
module Proofing
  module Aamva
    class HmacSecret
      KEY_SIZE_BYTES = 32
      SHA1_DIGEST_BYTES = 20

      attr_reader :client_secret, :server_secret, :psha1

      alias secret client_secret

      def initialize(encoded_client_secret, encoded_server_secret)
        @client_secret = Base64.decode64(encoded_client_secret)
        @server_secret = Base64.decode64(encoded_server_secret)
        calculate_psha1
      end

      private

      attr_writer :psha1

      def calculate_psha1
        self.psha1 = ''
        while psha1.length < KEY_SIZE_BYTES
          self.psha1 = psha1 + OpenSSL::HMAC.digest(
            digest,
            client_secret,
            next_a_value + server_secret,
          )
        end
        self.psha1 = psha1[0...KEY_SIZE_BYTES]
      end

      def next_a_value
        @a_value = OpenSSL::HMAC.digest(
          digest,
          client_secret,
          @a_value || server_secret,
        )
      end

      def digest
        @digest ||= OpenSSL::Digest.new('SHA1')
      end
    end
  end
end
