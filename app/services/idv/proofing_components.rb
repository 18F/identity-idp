# frozen_string_literal: true

module Idv
  class ProofingComponents
    def initialize(idv_session:, session:, user:, user_session:)
      @idv_session = idv_session
      @session = session
      @user = user
      @user_session = user_session
    end

    def document_check
      if user.establishing_in_person_enrollment || user.pending_in_person_enrollment
        Idp::Constants::Vendors::USPS
      elsif idv_session.remote_document_capture_complete?
        DocAuthRouter.doc_auth_vendor(
          request: nil,
          service_provider: idv_session.service_provider,
          session:,
          user_session:,
          user:,
        )
      end
    end

    def document_type
      return 'state_id' if idv_session.remote_document_capture_complete?
    end

    def source_check
      idv_session.source_check_vendor.presence ||
        (idv_session.verify_info_step_complete? && Idp::Constants::Vendors::AAMVA)
    end

    def resolution_check
      Idp::Constants::Vendors::LEXIS_NEXIS if idv_session.verify_info_step_complete?
    end

    def address_check
      if idv_session.verify_by_mail?
        'gpo_letter'
      elsif idv_session.address_verification_mechanism == 'phone'
        'lexis_nexis_address'
      end
    end

    def threatmetrix
      if idv_session.threatmetrix_review_status.present?
        FeatureManagement.proofing_device_profiling_collecting_enabled?
      end
    end

    def threatmetrix_review_status
      idv_session.threatmetrix_review_status
    end

    def to_h
      {
        document_check:,
        document_type:,
        source_check:,
        resolution_check:,
        address_check:,
        threatmetrix:,
        threatmetrix_review_status:,
      }.compact
    end

    private

    attr_reader :idv_session, :session, :user, :user_session
  end
end
