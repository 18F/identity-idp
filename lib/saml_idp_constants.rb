require 'idp/constants'

# rubocop:disable Layout/LineLength
# Global constants used by the SAML IdP
module Saml
  module Idp
    module Constants
      LOA1_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/1'.freeze
      LOA3_AUTHN_CONTEXT_CLASSREF = 'http://idmanagement.gov/ns/assurance/loa/3'.freeze

      IAL_AUTHN_CONTEXT_PREFIX = 'http://idmanagement.gov/ns/assurance/ial'.freeze
      IAL1_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/1".freeze
      IAL2_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/2".freeze
      IAL2_STRICT_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/2?strict=true".freeze
      IALMAX_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/0".freeze

      PASSWORD_AUTHN_CONTEXT_CLASSREFS = %w[
        urn:oasis:names:tc:SAML:2.0:ac:classes:Password
        urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport
      ].freeze
      DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF = 'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo'.freeze
      AAL_AUTHN_CONTEXT_PREFIX = 'http://idmanagement.gov/ns/assurance/aal'.freeze
      AAL1_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/1".freeze
      AAL2_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/2".freeze
      AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/2?phishing_resistant=true".freeze
      AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/2?hspd12=true".freeze
      AAL3_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/3".freeze
      AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/3?hspd12=true".freeze

      NAME_ID_FORMAT_PERSISTENT = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'.freeze
      NAME_ID_FORMAT_EMAIL = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'.freeze
      VALID_NAME_ID_FORMATS = [NAME_ID_FORMAT_PERSISTENT, NAME_ID_FORMAT_EMAIL].freeze

      REQUESTED_ATTRIBUTES_CLASSREF = 'http://idmanagement.gov/ns/requested_attributes?ReqAttr='.freeze

      VALID_AUTHN_CONTEXTS = IdentityConfig.store.valid_authn_contexts
      IAL2_AUTHN_CONTEXTS = [IAL2_AUTHN_CONTEXT_CLASSREF, LOA3_AUTHN_CONTEXT_CLASSREF].freeze

      AUTHN_CONTEXT_CLASSREF_TO_IAL = {
        LOA1_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL1,
        LOA3_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2,
        IAL1_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL1,
        IAL2_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2,
        IAL2_STRICT_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2_STRICT,
        IALMAX_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL_MAX,
      }.freeze

      AUTHN_CONTEXT_IAL_TO_CLASSREF = {
        ::Idp::Constants::IAL1 => IAL1_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::IAL2 => IAL2_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::IAL2_STRICT => IAL2_STRICT_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::IAL_MAX => IALMAX_AUTHN_CONTEXT_CLASSREF,
      }.freeze

      AUTHN_CONTEXT_CLASSREF_TO_AAL = {
        DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::DEFAULT_AAL,
        AAL1_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::AAL1,
        AAL2_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::AAL2,
        AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::AAL2,
        AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::AAL2,
        AAL3_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::AAL3,
        AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::AAL3,
      }.freeze

      AUTHN_CONTEXT_AAL_TO_CLASSREF = {
        ::Idp::Constants::DEFAULT_AAL => DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::AAL1 => AAL1_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::AAL2 => AAL2_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::AAL3 => AAL3_AUTHN_CONTEXT_CLASSREF,
      }.freeze
    end
  end
end
# rubocop:enable Layout/LineLength
