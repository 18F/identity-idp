# frozen_string_literal: true

class Proofing::LexisNexis::Decorators::InstantVerify::WithMdlOverrides
  OVERRIDE_CODES = [
    'occupancy_not_verified_fail',
    'unable_to_find_dl_fail',
  ].freeze

  def initialize(proofer)
    @proofer = proofer
    @overrides = []
  end

  # Calls orginal proofer proof method then attempts to apply overrides to the results.
  #
  # @param [Hash] applicant
  #
  # @return [Proofing::Resolution::Result] The overridden result if original result has failures
  # that could be overridden otherwise the original result it returned.
  def proof(applicant)
    apply_result_overrides(@proofer.proof(applicant))
  end

  private

  def apply_result_overrides(result)
    return result if result.success?

    successful_with_overrides = successful_with_overrides?(
      result.errors.dig(:"Execute Instant Verify", 0, 'Items'),
    )

    return result unless successful_with_overrides

    Proofing::Resolution::Result.new(
      success: successful_with_overrides,
      errors: result.errors,
      exception: result.exception,
      vendor_name: result.vendor_name,
      transaction_id: result.transaction_id,
      failed_result_can_pass_with_additional_verification:
        result.failed_result_can_pass_with_additional_verification,
      attributes_requiring_additional_verification:
        result.attributes_requiring_additional_verification,
      result_overrides: result.result_overrides + [{
        name: 'id_resolution_check_override',
        reason: 'mdl',
        overrides: @overrides,
      }],
    )
  end

  def successful_with_overrides?(errors)
    return false unless errors.present?

    failures = errors.filter { |item| item.dig('ItemStatus') == 'fail' }
    failures.any? && failures.all? { |item| overridden?(item) }
  end

  def overridden?(item)
    overridden = OVERRIDE_CODES.include?(item.dig('ItemReason', 'Code'))
    track_override(item) if overridden
    overridden
  end

  def track_override(item)
    @overrides << { item.dig('ItemName').to_sym => item.dig('ItemReason', 'Code') }
  end
end
