# frozen_string_literal: true

module Proofing
  module Resolution
    class ResultAdjudicator
      attr_reader :resolution_result,
                  :state_id_result,
                  :device_profiling_result,
                  :ipp_enrollment_in_progress,
                  :residential_resolution_result,
                  :phone_finder_result,
                  :same_address_as_id,
                  :applicant_pii

      def initialize(
        resolution_result:, # InstantVerify
        state_id_result:, # AAMVA
        residential_resolution_result:, # InstantVerify Residential
        phone_finder_result:, # PhoneFinder
        should_proof_state_id:,
        ipp_enrollment_in_progress:,
        device_profiling_result:, # ThreatMetrix
        same_address_as_id:,
        applicant_pii:
      )
        @resolution_result = resolution_result
        @state_id_result = state_id_result
        @should_proof_state_id = should_proof_state_id
        @ipp_enrollment_in_progress = ipp_enrollment_in_progress
        @device_profiling_result = device_profiling_result
        @residential_resolution_result = residential_resolution_result
        @phone_finder_result = phone_finder_result
        @same_address_as_id = same_address_as_id # this is a string, "true" or "false"
        @applicant_pii = applicant_pii
      end

      def adjudicated_result
        resolution_success, resolution_reason = resolution_result_and_reason
        device_profiling_success, device_profiling_reason = device_profiling_result_and_reason

        FormResponse.new(
          success: resolution_success && device_profiling_success,
          errors: errors,
          extra: {
            exception: exception,
            timed_out: timed_out?,
            threatmetrix_review_status: device_profiling_result.review_status,
            phone_finder_precheck_passed: phone_finder_result.success?,
            context: {
              device_profiling_adjudication_reason: device_profiling_reason,
              resolution_adjudication_reason: resolution_reason,
              should_proof_state_id: should_proof_state_id?,
              stages: {
                resolution: resolution_result.to_h,
                residential_address: residential_resolution_result.to_h,
                state_id: state_id_result.to_h,
                threatmetrix: device_profiling_result.to_h,
                phone_precheck: phone_finder_result.to_h,
              },
            },
            biographical_info: biographical_info,
          },
        )
      end

      def should_proof_state_id?
        @should_proof_state_id
      end

      private

      def errors
        resolution_result.errors
          .merge(residential_resolution_result.errors)
          .merge(state_id_result.errors)
          .merge(device_profiling_result.errors || {})
      end

      def exception
        resolution_result.exception ||
          residential_resolution_result.exception ||
          state_id_result.exception ||
          device_profiling_result.exception
      end

      def timed_out?
        resolution_result.timed_out? ||
          residential_resolution_result.timed_out? ||
          state_id_result.timed_out? ||
          device_profiling_result.timed_out?
      end

      def device_profiling_result_and_reason
        if device_profiling_result.exception?
          [false, :device_profiling_exception]
        elsif device_profiling_result.success?
          [true, :device_profiling_result_pass]
        else
          [true, :device_profiling_result_review_required]
        end
      end

      def resolution_result_and_reason
        if !residential_resolution_result.success? && same_address_as_id == 'false' &&
           ipp_enrollment_in_progress
          [false, :fail_resolution_skip_state_id]
        elsif resolution_result.success? && state_id_result.success?
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
        failed_resolution_attributes =
          resolution_result.attributes_requiring_additional_verification
        passed_state_id_attributes = state_id_result.verified_attributes

        (failed_resolution_attributes.to_a - passed_state_id_attributes.to_a).empty?
      end

      def biographical_info
        state_id_number = applicant_pii[:state_id_number]
        redacted_state_id_number = if state_id_number.present?
                                     StringRedacter.redact_alphanumeric(state_id_number)
                                   end
        {
          birth_year: applicant_pii[:dob]&.to_date&.year,
          state: applicant_pii[:state],
          identity_doc_address_state: applicant_pii[:identity_doc_address_state],
          state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
          state_id_number: redacted_state_id_number,
          same_address_as_id: applicant_pii[:same_address_as_id],
        }
      end
    end
  end
end
