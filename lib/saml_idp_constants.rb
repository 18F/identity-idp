# frozen_string_literal: true

require 'idp/constants'
# rubocop:disable Layout/LineLength
# Global constants used by the SAML IdP
module Saml
  module Idp
    module Constants
      LEGACY_ACR_NS = 'http://idmanagement.gov/ns'
      LEGACY_ACR_PREFIX = "#{LEGACY_ACR_NS}/assurance".freeze

      LOA1_AUTHN_CONTEXT_CLASSREF = "#{LEGACY_ACR_PREFIX}/loa/1".freeze
      LOA3_AUTHN_CONTEXT_CLASSREF = "#{LEGACY_ACR_PREFIX}/loa/3".freeze

      IAL_AUTHN_CONTEXT_PREFIX = "#{LEGACY_ACR_PREFIX}/ial".freeze
      IAL1_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/1".freeze
      IAL2_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/2".freeze
      IALMAX_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/0".freeze
      IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/2?bio=preferred".freeze
      IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF = "#{IAL_AUTHN_CONTEXT_PREFIX}/2?bio=required".freeze

      ACR_URN_NID = 'acr.login.gov'
      ACR_URN_PREFIX = "urn:#{ACR_URN_NID}".freeze
      IAL_AUTH_ONLY_ACR = "#{ACR_URN_PREFIX}:auth-only".freeze
      IAL_VERIFIED_ACR = "#{ACR_URN_PREFIX}:verified".freeze
      IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR = "#{ACR_URN_PREFIX}:verified-facial-match-required".freeze
      IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR = "#{ACR_URN_PREFIX}:verified-facial-match-preferred".freeze

      PASSWORD_AUTHN_CONTEXT_CLASSREFS = %w[
        urn:oasis:names:tc:SAML:2.0:ac:classes:Password
        urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport
      ].freeze

      DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF = 'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo'
      AAL_AUTHN_CONTEXT_PREFIX = "#{LEGACY_ACR_PREFIX}/aal".freeze
      AAL1_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/1".freeze
      AAL2_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/2".freeze
      AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/2?phishing_resistant=true".freeze
      AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/2?hspd12=true".freeze
      AAL3_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/3".freeze
      AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF = "#{AAL_AUTHN_CONTEXT_PREFIX}/3?hspd12=true".freeze

      NAME_ID_FORMAT_PERSISTENT = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
      NAME_ID_FORMAT_EMAIL = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
      NAME_ID_FORMAT_UNSPECIFIED = 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
      VALID_NAME_ID_FORMATS = [NAME_ID_FORMAT_PERSISTENT, NAME_ID_FORMAT_EMAIL].freeze

      REQUESTED_ATTRIBUTES_CLASSREF = "#{LEGACY_ACR_NS}/requested_attributes?ReqAttr=".freeze

      # TODO: replace valid_authn_contexts_semantic with valid_authn_contexts
      VALID_AUTHN_CONTEXTS = IdentityConfig.store.valid_authn_contexts_semantic.freeze

      FACIAL_MATCH_IAL_CONTEXTS = [
        IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
        IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR,
        IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
        IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
      ].freeze

      FACIAL_MATCH_REQUIRED_IAL_CONTEXTS = [
        IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
        IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
      ].freeze

      IAL2_AUTHN_CONTEXTS = [
        *FACIAL_MATCH_IAL_CONTEXTS,
        IAL_VERIFIED_ACR,
        IAL2_AUTHN_CONTEXT_CLASSREF,
        LOA3_AUTHN_CONTEXT_CLASSREF,
      ].freeze

      AUTHN_CONTEXT_CLASSREF_TO_IAL = {
        LOA1_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL1,
        LOA3_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2,
        IAL1_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL1,
        IAL2_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2,
        IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2,
        IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL2,
        IALMAX_AUTHN_CONTEXT_CLASSREF => ::Idp::Constants::IAL_MAX,
        IAL_AUTH_ONLY_ACR => ::Idp::Constants::IAL1,
        IAL_VERIFIED_ACR => ::Idp::Constants::IAL2,
        IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR => ::Idp::Constants::IAL2,
        IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR => ::Idp::Constants::IAL2,
      }.freeze

      AUTHN_CONTEXT_IAL_TO_CLASSREF = {
        ::Idp::Constants::IAL1 => IAL1_AUTHN_CONTEXT_CLASSREF,
        ::Idp::Constants::IAL2 => IAL2_AUTHN_CONTEXT_CLASSREF,
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

      SEMANTIC_ACRS = [
        IAL_AUTH_ONLY_ACR,
        IAL_VERIFIED_ACR,
        IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR,
        IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
      ].freeze

      LEGACY_ACRS_TO_SEMANTIC_ACRS = {
        LOA1_AUTHN_CONTEXT_CLASSREF => IAL_AUTH_ONLY_ACR,
        LOA3_AUTHN_CONTEXT_CLASSREF => IAL_VERIFIED_ACR,
        IAL1_AUTHN_CONTEXT_CLASSREF => IAL_AUTH_ONLY_ACR,
        IAL2_AUTHN_CONTEXT_CLASSREF => IAL_VERIFIED_ACR,
        IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF => IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR,
        IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF => IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
      }.freeze
    end
  end
end
# rubocop:enable Layout/LineLength
