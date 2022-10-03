# frozen_string_literal: true

module Proofing
  module Mock
    class StateIdMockClient < Proofing::Base
      SUPPORTED_STATE_ID_TYPES = %w[
        drivers_license drivers_permit state_id_card
      ].to_set.freeze

      INVALID_STATE_ID_NUMBER = '00000000'
      TRANSACTION_ID = 'state-id-mock-transaction-id-456'
      TRIGGER_MVA_TIMEOUT = 'mvatimeout'

      StateIdMockClientResult = Struct.new(:success, :errors, :exception, keyword_init: true) do
        def success?
          success
        end

        def timed_out?
          exception.is_a?(Proofing::TimeoutError)
        end

        def transaction_id
          TRANSACTION_ID
        end

        def to_h
          {
            exception: exception,
            errors: errors,
            success: success,
            timed_out: timed_out?,
            transaction_id: transaction_id,
            vendor_name: 'StateIdMock',
          }
        end
      end

      def proof(applicant)
        return mva_timeout_result if applicant[:state_id_number].downcase == TRIGGER_MVA_TIMEOUT

        errors = {}
        if state_not_supported?(applicant[:state_id_jurisdiction])
          errors[:state_id_jurisdiction] = ['The jurisdiction could not be verified']
        elsif invalid_state_id_number?(applicant[:state_id_number])
          errors[:state_id_number] = ['The state ID number could not be verified']
        elsif invalid_state_id_type?(applicant[:state_id_type])
          errors[:state_id_type] = ['The state ID type could not be verified']
        end

        return unverifiable_result(errors) if errors.any?

        StateIdMockClientResult.new(success: true, errors: {}, exception: nil)
      end

      private

      def mva_timeout_result
        StateIdMockClientResult.new(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new(
            'ExceptionId: 0047, ExceptionText: MVA did not respond in a timely fashion',
          ),
        )
      end

      def unverifiable_result(errors)
        StateIdMockClientResult.new(
          success: false,
          errors: errors,
          exception: nil,
        )
      end

      def state_not_supported?(state_id_jurisdiction)
        !IdentityConfig.store.aamva_supported_jurisdictions.include? state_id_jurisdiction
      end

      def invalid_state_id_number?(state_id_number)
        state_id_number =~ /\A0*\z/
      end

      def invalid_state_id_type?(state_id_type)
        !SUPPORTED_STATE_ID_TYPES.include?(state_id_type) ||
          state_id_type.nil?
      end
    end
  end
end
