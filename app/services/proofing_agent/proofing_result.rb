# frozen_string_literal: true

module ProofingAgent
  class ProofingResult
    attr_reader :proofing_agent_id,
                :proofing_location_id,
                :correlation_id,
                :resolution_result,
                :aamva_result,
                :mrz_result

    def initialize(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      resolution_result:,
      aamva_result: nil,
      mrz_result: nil
    )
      @proofing_agent_id = proofing_agent_id
      @proofing_location_id = proofing_location_id
      @correlation_id = correlation_id
      @resolution_result = resolution_result
      @aamva_result = aamva_result&.to_h
      @mrz_result = mrz_result&.to_h
    end

    def combined_result
      reason = determine_failure_reason
      success = reason.nil?

      result = { success:, reason: }

      if resolution_result.present?
        result[:resolution] =
          resolution_result.slice(:success, :errors, :exception)
      end
      result[:aamva] = aamva_result if aamva_result.present?
      result[:mrz] = mrz_result if mrz_result.present?

      result
    end

    private

    def determine_failure_reason
      if resolution_result.present? && resolution_result[:exception].present?
        return 'profile_resolution_exception'
      end
      return 'id_exception' if aamva_result.present? && aamva_result[:exception].present?
      return 'passport_exception' if mrz_result.present? && mrz_result[:exception].present?

      return 'profile_resolution_fail' if resolution_result.present? && !resolution_result[:success]
      return 'id_fail' if aamva_result.present? && !aamva_success?
      return 'passport_fail' if mrz_result.present? && !mrz_result[:success]

      nil
    end

    def aamva_success?
      aamva_result[:success] || aamva_skipped?
    end

    def aamva_skipped?
      [
        Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED,
        Idp::Constants::Vendors::AAMVA_UNSUPPORTED_JURISDICTION,
      ].include?(aamva_result[:vendor_name])
    end
  end
end
