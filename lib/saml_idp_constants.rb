# Global constants used by the SAML IdP
module Saml
  module Idp
    module Constants
      LOA1_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/1'.freeze
      LOA3_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/3'.freeze
      REQUESTED_ATTRIBUTES_CLASSREF = 'http://idmanagement.gov/ns/requested_attributes?ReqAttr='.freeze

      VALID_AUTHN_CONTEXTS = JSON.parse(Figaro.env.valid_authn_contexts).freeze
    end
  end
end
