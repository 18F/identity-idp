# rubocop:disable Metrics/ParameterLists
module JWT
  module_function

  def decode_verify_signature(key, header, payload, signature, signing_input, options, &keyfinder)
    algo, key = signature_algorithm_and_key(header, payload, key, &keyfinder)

    allowed_a = allowed_algorithms(options)
    raise(JWT::IncorrectAlgorithm, 'An algorithm must be specified') if allowed_a.empty?
    unless allowed_a.include?(algo) || algo.to_s.include?('Proc:') # login.gov mod for CloudHsm
      raise(JWT::IncorrectAlgorithm, 'Expected a different algorithm')
    end

    Signature.verify(algo, key, signing_input, signature)
  end

  class Encode
    def encoded_signature(signing_input)
      return '' if @algorithm == 'none'
      signature = if @algorithm.class == Proc # login.gov mod for CloudHsm
                    @algorithm.call(signing_input, @key)
                  else
                    JWT::Signature.sign(@algorithm, signing_input, @key)
                  end
      Encode.base64url_encode(signature)
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
# rubocop:enable Metrics/ParameterLists
