# Global constants used by the SAML IdP
module Saml
  module Idp
    module Constants
      LOA1_AUTHNCONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/1'.freeze
      LOA2_AUTHNCONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/2'.freeze
      LOA3_AUTHNCONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/3'.freeze
      LOA4_AUTHNCONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/4'.freeze

      VALID_AUTHNCONTEXTS = [
        LOA1_AUTHNCONTEXT_CLASSREF,
        LOA2_AUTHNCONTEXT_CLASSREF,
        LOA3_AUTHNCONTEXT_CLASSREF,
        LOA4_AUTHNCONTEXT_CLASSREF
      ].freeze
    end
  end
end
