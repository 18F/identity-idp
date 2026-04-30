# frozen_string_literal: true

module Idv
  module ProofingAgent
    AgentProofedUser = RedactedStruct.new(
      :id,
      :pii,
      :proofing_components,
      :proofing_location_id,
      :proofing_agent_id,
      :correlation_id,
      :transaction_id,
      :issuer,
      :doc_auth_success,
      :reason,
      :resolution,                # instant_verify/socure_kyc
      :mrz_status,                # DoS
      :aamva_status,              # aamva
      :aamva_verified_attributes,
      :source_check_vendor,
      :address_resolution_status, # phone_finder
      :captured_at,
      allowed_members: [
        :proofing_components,
        :proofing_location_id,
        :proofing_agent_id,
        :correlation_id,
        :transaction_id,
        :issuer,
        :doc_auth_success,
        :reason,
        :resolution,
        :mrz_status,
        :aamva_status,
        :aamva_verified_attributes,
        :source_check_vendor,
        :address_resolution_status,
        :captured_at,
      ],
    ) do
      def self.redis_key_prefix
        'proofing_agent:result'
      end

      def success?
        doc_auth_success &&
          (aamva_status == :passed || mrz_status == :pass)
      end

      def mrz_status
        self[:mrz_status]&.to_sym
      end

      def aamva_status
        self[:aamva_status]&.to_sym
      end

      def source_check_vendor
        self[:source_check_vendor]&.to_sym
      end

      def aamva_verified_attributes
        self[:aamva_verified_attributes] || []
      end

      def address_resolution_status
        self[:address_resolution_status]&.to_sym
      end

      # This hash should be merged into the idv_session in order to populate proofing components in
      # the event logs.
      def proofing_components
        if success?
          {
            doc_auth_vendor:,
            document_type_received: pii[:document_type_received],
            source_check_vendor:,
            resolution_vendor: resolution&.dig(
              :context, :stages, :resolution, :vendor_name
            ),
            residential_resolution_vendor: resolution&.dig(
              :context, :stages, :residential_address, :vendor_name
            ),
            verify_info_step_complete: resolution&.dig(:success),
            phone_precheck_vendor: resolution&.dig(
              :context, :stages, :phone_precheck, :vendor_name
            ),
            threat_metrix_review_status: resolution&.dig(
              :context, :stages, :threatmetrix, :review_status
            ),
          }
        end
      end

      alias_method :pii_from_doc, :pii
    end.freeze
  end
end
