module JWT
  module Signature
    def sign(algorithm, signing_input, key)
      SamlAndOidcSigner.sign(algorithm, signing_input, key)
    end
  end
end
