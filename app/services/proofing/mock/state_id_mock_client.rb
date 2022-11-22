# frozen_string_literal: true

module Proofing
  module Mock
    class StateIdMockClient
      SUPPORTED_STATE_ID_TYPES = %w[
        drivers_license drivers_permit state_id_card
      ].to_set.freeze

      INVALID_STATE_ID_NUMBER = '00000000'
      TRANSACTION_ID = 'state-id-mock-transaction-id-456'
      TRIGGER_MVA_TIMEOUT = 'mvatimeout'

      def proof(applicant)
        return mva_timeout_result if mva_timeout?(applicant[:state_id_number])

        errors = {}
        if state_not_supported?(applicant[:state_id_jurisdiction])
          errors[:state_id_jurisdiction] = ['The jurisdiction could not be verified']
        elsif invalid_state_id_number?(applicant[:state_id_number])
          errors[:state_id_number] = ['The state ID number could not be verified']
        elsif invalid_state_id_type?(applicant[:state_id_type])
          errors[:state_id_type] = ['The state ID type could not be verified']
        end

        return unverifiable_result(errors) if errors.any?

        StateIdResult.new(
          success: true,
          errors: {},
          exception: nil,
          vendor_name: 'StateIdMock',
          transaction_id: TRANSACTION_ID,
        )
      end

      private

      def mva_timeout_result
        StateIdResult.new(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new(
            'ExceptionId: 0047, ExceptionText: MVA did not respond in a timely fashion',
          ),
          vendor_name: 'StateIdMock',
          transaction_id: TRANSACTION_ID,
        )
      end

      def unverifiable_result(errors)
        StateIdResult.new(
          success: false,
          errors: errors,
          exception: nil,
          vendor_name: 'StateIdMock',
          transaction_id: TRANSACTION_ID,
        )
      end

      def mva_timeout?(state_id_number)
        return false if state_id_number.blank?
        state_id_number.downcase == TRIGGER_MVA_TIMEOUT
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
