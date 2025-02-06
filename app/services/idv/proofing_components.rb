# frozen_string_literal: true

module Idv
  class ProofingComponents
    def initialize(idv_session:)
      @idv_session = idv_session
    end

    def document_check
      idv_session.doc_auth_vendor
    end

    def document_type
      return 'state_id' if idv_session.remote_document_capture_complete?
    end

    def source_check
      idv_session.source_check_vendor.presence ||
        (idv_session.verify_info_step_complete? && Idp::Constants::Vendors::AAMVA)
    end

    def residential_resolution_check
      idv_session.residential_resolution_vendor if idv_session.verify_info_step_complete?
    end

    def resolution_check
      idv_session.resolution_vendor if idv_session.verify_info_step_complete?
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
        residential_resolution_check:,
        resolution_check:,
        address_check:,
        threatmetrix:,
        threatmetrix_review_status:,
      }.compact
    end

    private

    attr_reader :idv_session
  end
end
