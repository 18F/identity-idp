# rubocop:disable all
module JWT
  class Decode
    def verify_signature
      @key = find_key(&@keyfinder) if @keyfinder
      @key = ::JWT::JWK::KeyFinder.new(jwks: @options[:jwks]).key_for(header['kid']) if @options[:jwks]

      raise(JWT::IncorrectAlgorithm, 'An algorithm must be specified') if allowed_algorithms.empty?
      unless options_includes_algo_in_header? || header['alg'].include?('Proc:')
        raise(JWT::IncorrectAlgorithm, 'Expected a different algorithm') unless options_includes_algo_in_header?
      end

      Signature.verify(header['alg'], @key, signing_input, @signature)
    end
  end

  class Encode
    def encode_signature
      return '' if @algorithm == 'none'
      signature = if @algorithm.class == Proc # login.gov mod for CloudHsm
                    @algorithm.call(encoded_header_and_payload, @key)
                  else
                    JWT::Signature.sign(@algorithm, encoded_header_and_payload, @key)
                  end
      JWT::Base64.url_encode(signature)
    end
  end
end

module JWT
  module Algos
    module Unsupported
      module_function

      def verify(to_verify)
        return true if to_verify.algorithm.to_s.include?('Proc:') # login.gov mod for CloudHsm
        raise JWT::VerificationError, 'Algorithm not supported'
      end
    end
  end
end
# rubocop:enable all
