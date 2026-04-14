# frozen_string_literal: true

module Idv
  module ProofingAgent
    AgentProofedUser = RedactedStruct.new(
      :id,
      :pii,
      :proofing_components,
      :location_id,
      :agent_id,
      :issuer,
      :success,
      :errors,
      :doc_auth_success,          # trueid/socure
      :mrz_status,                # DoS
      :aamva_status,              # aamva
      :aamva_verified_attributes,
      :address_resolution_status, # phone_finder/kyc
      :state_id_vendor,
      :attempt,
      :captured_at,
      allowed_members: [
        :proofing_components,
        :location_id,
        :agent_id,
        :issuer,
        :success,
        :errors,
        :doc_auth_success,
        :mrz_status,
        :aamva_status,
        :aamva_verified_attributes,
        :address_resolution_status,
        :state_id_vendor,
        :attempt,
        :captured_at,
      ],
    ) do
      def self.redis_key_prefix
        'proofing_agent:result'
      end

      def mrz_status
        self[:mrz_status]&.to_sym
      end

      def aamva_status
        self[:aamva_status]&.to_sym
      end

      def state_id_vendor
        self[:state_id_vendor]&.to_sym
      end

      def aamva_verified_attributes
        self[:aamva_verified_attributes] || []
      end

      def address_resolution_status
        self[:address_resolution_status]&.to_sym
      end

      alias_method :success?, :success
      alias_method :pii_from_doc, :pii
    end.freeze
  end
end
