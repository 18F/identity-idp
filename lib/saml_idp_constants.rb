# Global constants used by the SAML IdP
module Saml
  module Idp
    # :reek:TooManyConstants
    module Constants
      LOA1_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/1'.freeze
      LOA3_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/3'.freeze

      # For now the acr values returned are still LOA
      IAL1_AUTHN_CONTEXT_CLASSREF = LOA1_AUTHN_CONTEXT_CLASSREF
      IAL2_AUTHN_CONTEXT_CLASSREF = LOA3_AUTHN_CONTEXT_CLASSREF

      REQUESTED_ATTRIBUTES_CLASSREF = 'http://idmanagement.gov/ns/requested_attributes?ReqAttr='.freeze

      VALID_AUTHN_CONTEXTS = JSON.parse(Figaro.env.valid_authn_contexts).freeze
    end
  end
end
