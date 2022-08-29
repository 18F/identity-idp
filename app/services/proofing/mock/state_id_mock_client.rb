# frozen_string_literal: true

module Proofing
  module Mock
    class StateIdMockClient < Proofing::Base
      vendor_name 'StateIdMock'

      required_attributes :uuid,
                          :first_name,
                          :last_name,
                          :dob,
                          :state_id_number,
                          :state_id_type,
                          :state_id_jurisdiction

      optional_attributes :uuid_prefix

      stage :state_id

      SUPPORTED_STATE_ID_TYPES = %w[
        drivers_license drivers_permit state_id_card
      ].to_set.freeze

      INVALID_STATE_ID_NUMBER = '00000000'
      TRANSACTION_ID = 'state-id-mock-transaction-id-456'
      TRIGGER_MVA_TIMEOUT = 'mvatimeout'

      proof do |applicant, result|
        if applicant[:state_id_number].downcase == TRIGGER_MVA_TIMEOUT
          raise ::Proofing::TimeoutError.new(
            'ExceptionId: 0047, ExceptionText: MVA did not respond in a timely fashion',
          )
        end

        if state_not_supported?(applicant[:state_id_jurisdiction])
          result.add_error(:state_id_jurisdiction, 'The jurisdiction could not be verified')

        elsif invalid_state_id_number?(applicant[:state_id_number])
          result.add_error(:state_id_number, 'The state ID number could not be verified')

        elsif invalid_state_id_type?(applicant[:state_id_type])
          result.add_error(:state_id_type, 'The state ID type could not be verified')
        end

        result.transaction_id = TRANSACTION_ID
      end

      private

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
