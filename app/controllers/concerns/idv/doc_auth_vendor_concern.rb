# frozen_string_literal: true

module Idv
  module DocAuthVendorConcern
    include AbTestingConcern

    # @returns[String] String identifying the vendor to use for doc auth.
    def doc_auth_vendor
      document_capture_session.doc_auth_vendor || begin
        if resolved_authn_context_result.facial_match? || socure_user_set.maxed_users?
          bucket = choose_non_socure_bucket
        else
          bucket = ab_test_bucket(:DOC_AUTH_VENDOR)
        end

        if bucket == :socure
          if !add_user_to_socure_set
            bucket = choose_non_socure_bucket # force to lexis_nexis if max user reached
          end
        end

        doc_auth_vendor_for_bucket = DocAuthRouter.doc_auth_vendor_for_bucket(bucket)
        document_capture_session.update!(doc_auth_vendor: doc_auth_vendor_for_bucket)
        doc_auth_vendor_for_bucket
      end
    end

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

    def vendor_document_capture_url
      case doc_auth_vendor
      when Idp::Constants::Vendors::SOCURE
        idv_socure_document_capture_url
      when Idp::Constants::Vendors::LEXIS_NEXIS
        idv_document_capture_url
      else
        idv_document_capture_url
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

    def add_user_to_socure_set
      uuid = current_user&.uuid
      if uuid.nil? && defined?(document_capture_user)
        uuid = document_capture_user&.uuid
      end

      if uuid
        return socure_user_set.add_user!(user_uuid: uuid)
      end

      false
    end
  end
end
