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
      @aamva_result = aamva_result
      @mrz_result = mrz_result
    end

    def combined_result
      reason = determine_failure_reason
      success = reason.nil?

      result = { success:, reason: }

      result[:resolution] = resolution_result.slice(:success, :errors, :exception) if resolution_result.present?
      result[:aamva] = aamva_result.to_h if aamva_result.present?
      result[:mrz] = mrz_result.to_h if mrz_result.present?

      result
    end

    private

    def determine_failure_reason
      return 'resolution_exception' if resolution_result.present? && resolution_result[:exception].present?
      return 'aamva_exception' if aamva_result.present? && aamva_result.exception.present?
      return 'mrz_exception' if mrz_result.present? && mrz_result.exception.present?

      return 'resolution_failed' if resolution_result.present? && !resolution_result[:success]
      return 'aamva_failed' if aamva_result.present? && !aamva_success?
      return 'mrz_failed' if mrz_result.present? && !mrz_result.success?

      nil
    end

    def aamva_success?
      aamva_result.success? || aamva_skipped?
    end

    def aamva_skipped?
      [
        Idp::Constants::Vendors::AAMVA_CHECK_SKIPPED,
        Idp::Constants::Vendors::AAMVA_UNSUPPORTED_JURISDICTION,
      ].include?(aamva_result.vendor_name)
    end
  end
end
