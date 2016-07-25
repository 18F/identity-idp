# Global constants used by the SAML IdP
module Saml
  module Idp
    module Constants
      LOA1_AUTHNCONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/1'.freeze
      LOA3_AUTHNCONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/3'.freeze

      VALID_AUTHNCONTEXTS = [
        LOA1_AUTHNCONTEXT_CLASSREF,
        LOA3_AUTHNCONTEXT_CLASSREF
      ].freeze
    end
  end
end
