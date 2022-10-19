module Proofing
  class ResolutionResultAdjudicator
    attr_reader :resolution_result, :state_id_result, :should_proof_state_id

    def initialize(resolution_result:, state_id_result:, should_proof_state_id:)
      @resolution_result = resolution_result
      @state_id_result = state_id_result
      @should_proof_state_id = should_proof_state_id
    end

    def adjudicated_result
      FormResponse.new(
        success: success?,
        errors: resolution_result.errors.merge(state_id_result.errors),
        extra: {
          exception: resolution_result.exception || state_id_result.exception,
          timed_out: resolution_result.timed_out? || state_id_result.timed_out?,
          context: {
            should_proof_state_id: should_proof_state_id,
            stages: {
              resolution: resolution_result.to_h,
              state_id: state_id_result.to_h,
            },
          },
        },
      )
    end

    private

    def success?
      return true if resolution_result.success? && state_id_result.success?
      return false unless should_proof_state_id
      return true if state_id_attributes_cover_resolution_failures?
      false
    end

    def state_id_attributes_cover_resolution_failures?
      return false unless resolution_result.failed_result_can_pass_with_additional_verification?
      failed_resolution_attributes = resolution_result.attributes_requiring_additional_verification
      passed_state_id_attributes = state_id_result.verified_attributes

      (failed_resolution_attributes - passed_state_id_attributes).empty?
    end
  end
end
