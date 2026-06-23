# frozen_string_literal: true

module ProofingAgent
  class ProofingResult
    attr_reader :proofing_agent_id,
                :proofing_location_id,
                :correlation_id,
                :transaction_id,
                :pii,
                :resolution_result,
                :aamva_result,
                :mrz_result,
                :service_provider_issuer,
                :system_error

    def initialize(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      transaction_id:,
      resolution_result:,
      service_provider_issuer:,
      pii:,
      aamva_result: nil,
      mrz_result: nil,
      system_error: nil
    )
      @proofing_agent_id = proofing_agent_id
      @proofing_location_id = proofing_location_id
      @correlation_id = correlation_id
      @transaction_id = transaction_id
      @pii = pii
      @resolution_result = resolution_result
      @aamva_result = aamva_result&.to_h
      @mrz_result = mrz_result&.to_h
      @service_provider_issuer = service_provider_issuer
      @system_error = system_error
    end

    def combined_result
      reason = determine_failure_reason
      success = reason.nil?

      result = {
        success:,
        reason:,
        service_provider_issuer:,
        proofing_agent_id:,
        proofing_location_id:,
        correlation_id:,
        transaction_id:,
      }

      result[:pii] = pii if pii.present?
      result[:resolution] = resolution_result if resolution_result.present?
      result[:aamva] = aamva_result if aamva_result.present?
      result[:mrz] = mrz_result if mrz_result.present?

      result
    end

    def phone_precheck_attempted?
      resolution_result.dig(:context, :stages, :phone_precheck).present?
    end

    private

    def determine_failure_reason
      return 'system_error' if system_error.present? || all_vendor_results_missing?

      if resolution_result.present? && resolution_result[:exception].present?
        return 'profile_resolution_exception'
      end
      return 'id_exception' if aamva_result.present? && aamva_result[:exception].present?
      return 'passport_exception' if mrz_result.present? && mrz_result[:exception].present?

      return 'profile_resolution_fail' if resolution_result.present? && !resolution_result[:success]
      return 'id_fail' if aamva_result.present? && !aamva_success?
      return 'passport_fail' if mrz_result.present? && !mrz_result[:success]
      return 'phone_check_fail' if !phone_precheck_attempted? || !phone_precheck_passed?
    end

    def all_vendor_results_missing?
      resolution_result.blank? && aamva_result.blank? && mrz_result.blank?
    end

    def phone_precheck_passed?
      resolution_result[:phone_precheck_passed]
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
