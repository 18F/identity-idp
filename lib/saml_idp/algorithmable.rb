module SamlIdp
  module Algorithmable
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

    def algorithm_name
      algorithm.to_s.split('::').last.downcase
    end
    private :algorithm_name
  end
end
