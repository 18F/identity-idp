require 'saml_idp/attributeable'
module SamlIdp
  class PersistedMetadata
    include Attributeable

    def sign_assertions?
      !!attributes[:sign_assertions]
    end
  end
end
