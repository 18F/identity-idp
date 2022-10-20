module Proofing
  class ResolutionResultAdjudicator
    attr_reader :resolution_result, :state_id_result

    def initialize(resolution_result:, state_id_result:, should_proof_state_id:)
      @resolution_result = resolution_result
      @state_id_result = state_id_result
      @should_proof_state_id = should_proof_state_id
    end

    def adjudicated_result
      success, adjudication_reason = result_and_adjudication_reason
      FormResponse.new(
        success: success,
        errors: resolution_result.errors.merge(state_id_result.errors),
        extra: {
          exception: resolution_result.exception || state_id_result.exception,
          timed_out: resolution_result.timed_out? || state_id_result.timed_out?,
          context: {
            adjudication_reason: adjudication_reason,
            should_proof_state_id: should_proof_state_id?,
            stages: {
              resolution: resolution_result.to_h,
              state_id: state_id_result.to_h,
            },
          },
        },
      )
    end

    def should_proof_state_id?
      @should_proof_state_id
    end

    private

    def result_and_adjudication_reason
      if resolution_result.success? && state_id_result.success?
        [true, :pass_resolution_and_state_id]
      elsif !state_id_result.success?
        [false, :fail_state_id]
      elsif !should_proof_state_id?
        [false, :fail_resolution_skip_state_id]
      elsif state_id_attributes_cover_resolution_failures?
        [true, :state_id_covers_failed_resolution]
      else
        [false, :fail_resolution_without_state_id_coverage]
      end
    end

    def state_id_attributes_cover_resolution_failures?
      return false unless resolution_result.failed_result_can_pass_with_additional_verification?
      failed_resolution_attributes = resolution_result.attributes_requiring_additional_verification
      passed_state_id_attributes = state_id_result.verified_attributes

      (failed_resolution_attributes.to_a - passed_state_id_attributes.to_a).empty?
    end
  end
end
