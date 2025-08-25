# frozen_string_literal: true

module Idv
  module DocAuthVendorConcern
    include AbTestingConcern

    def doc_auth_vendor_enabled?(vendor)
      return true if IdentityConfig.store.doc_auth_vendor_default == vendor
      return false unless IdentityConfig.store.doc_auth_vendor_switching_enabled

      case vendor
      when Idp::Constants::Vendors::SOCURE
        IdentityConfig.store.doc_auth_vendor_socure_percent > 0
      when Idp::Constants::Vendors::LEXIS_NEXIS
        IdentityConfig.store.doc_auth_vendor_lexis_nexis_percent > 0
      else
        false
      end
    end

    def doc_auth_selfie_vendor_enabled?(vendor)
      return true if IdentityConfig.store.doc_auth_selfie_vendor_default == vendor
      return false unless IdentityConfig.store.doc_auth_selfie_vendor_switching_enabled

      case vendor
      when Idp::Constants::Vendors::SOCURE
        IdentityConfig.store.doc_auth_selfie_vendor_socure_percent > 0
      when Idp::Constants::Vendors::LEXIS_NEXIS
        IdentityConfig.store.doc_auth_selfie_vendor_lexis_nexis_percent > 0
      else
        false
      end
    end

    def update_doc_auth_vendor(user: current_user)
      if document_capture_session.doc_auth_vendor.blank?
        document_capture_session.update!(doc_auth_vendor: bucketed_doc_auth_vendor(user))
      end
    end

    private

    def choose_non_socure_bucket
      if doc_auth_vendor_enabled?(Idp::Constants::Vendors::LEXIS_NEXIS)
        :lexis_nexis
      elsif doc_auth_vendor_enabled?(Idp::Constants::Vendors::MOCK)
        :mock
      end
    end

    def socure_user_set
      @socure_user_set ||= SocureUserSet.new
    end

    def add_user_to_socure_set(user)
      if user&.uuid
        return socure_user_set.add_user!(user_uuid: user.uuid)
      end

      false
    end

    # @returns[String] String identifying the vendor to use for doc auth.
    def bucketed_doc_auth_vendor(user)
      @bucketed_doc_auth_vendor ||= begin
        bucket = nil
        if socure_user_set.maxed_users?
          bucket = choose_non_socure_bucket
        elsif resolved_authn_context_result.facial_match?
          if document_capture_session.passport_requested?
            bucket = choose_non_socure_bucket # todo: intro A/B passport selfie vendor
          else
            bucket = ab_test_bucket(:DOC_AUTH_SELFIE_VENDOR, user:)
          end
        elsif document_capture_session.passport_requested?
          bucket = ab_test_bucket(:DOC_AUTH_PASSPORT_VENDOR, user:)
        else
          bucket = ab_test_bucket(:DOC_AUTH_VENDOR, user:)
        end

        if bucket == :socure
          if !add_user_to_socure_set(user)
            bucket = choose_non_socure_bucket # force to lexis_nexis if max user reached
          end
        end

        DocAuthRouter.doc_auth_vendor_for_bucket(
          bucket,
          selfie: resolved_authn_context_result.facial_match?,
          passport_requested: document_capture_session.passport_requested?,
        )
      end
    end
  end
end
