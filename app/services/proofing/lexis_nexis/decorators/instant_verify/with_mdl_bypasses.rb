# frozen_string_literal: true

class Proofing::LexisNexis::Decorators::InstantVerify::WithMdlBypasses
  def initialize(proofer)
    @proofer = proofer
    @bypasses = []
  end

  # Calls orginal proofer proof method then attempts to apply bypasses to the results.
  #
  # @param [Hash] applicant
  #
  # @return [Proofing::Resolution::Result] The bypassed result if original result has failures
  # that could be bypassed otherwise the original result it returned.
  def proof(applicant)
    result = @proofer.proof(applicant)

    return result if result.success? || result.exception.present?

    apply_result_bypasses(result)
  end

  private

  def apply_result_bypasses(result)
    successful_with_bypasses = successful_with_bypasses?(
      result.errors.dig(:InstantVerify, 0, 'Items'),
    )

    return result unless successful_with_bypasses

    Proofing::Resolution::Result.new(
      success: successful_with_bypasses,
      errors: result.errors,
      exception: result.exception,
      vendor_name: result.vendor_name,
      transaction_id: result.transaction_id,
      failed_result_can_pass_with_additional_verification:
        result.failed_result_can_pass_with_additional_verification,
      attributes_requiring_additional_verification:
        result.attributes_requiring_additional_verification,
      bypassed_reason_codes: result.bypassed_reason_codes + [{
        name: 'id_resolution_check_bypassed',
        reason: 'mdl',
        bypassed_checks: @bypasses,
      }],
    )
  end

  def successful_with_bypasses?(errors)
    return false unless errors.present?

    failures = errors.filter { |item| item.dig('ItemStatus') == 'fail' }
    failures.any? && failures.all? { |item| bypassable?(item) }
  end

  def bypassable?(item)
    overridden = bypassable_item?(item)
    track_bypass(item) if overridden
    overridden
  end

  def bypassable_item?(item)
    !!bypass_codes[item.dig('ItemName')]&.include?(item.dig('ItemReason', 'Code'))
  end

  def bypass_codes
    IdentityConfig.store.idv_lexis_nexis_instant_verify_mdl_bypass_error_codes
      .with_indifferent_access
  end

  def track_bypass(item)
    @bypasses << { item.dig('ItemName').to_sym => item.dig('ItemReason', 'Code') }
  end
end
