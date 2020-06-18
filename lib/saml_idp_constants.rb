# Global constants used by the SAML IdP
module Saml
  module Idp
    module Constants
      LOA1_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/1'.freeze
      LOA3_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/3'.freeze
      IAL1_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/ial/1'.freeze
      IAL2_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/ial/2'.freeze
      IALMAX_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/ial/0'.freeze

      REQUESTED_ATTRIBUTES_CLASSREF = 'http://idmanagement.gov/ns/requested_attributes?ReqAttr='.freeze

      VALID_AUTHN_CONTEXTS = JSON.parse(Figaro.env.valid_authn_contexts).freeze
      IAL2_AUTHN_CONTEXTS = [IAL2_AUTHN_CONTEXT_CLASSREF, LOA3_AUTHN_CONTEXT_CLASSREF].freeze
    end
  end
end
