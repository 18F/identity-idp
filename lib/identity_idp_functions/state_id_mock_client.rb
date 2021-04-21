# frozen_string_literal: true

require 'proofer'

module IdentityIdpFunctions
  class StateIdMockClient < Proofer::Base
    vendor_name 'StateIdMock'

    required_attributes :state_id_number, :state_id_type, :state_id_jurisdiction

    optional_attributes :uuid, :uuid_prefix

    stage :state_id

    SUPPORTED_STATES = %w[
      AR AZ CO CT DC DE FL GA IA ID IL IN KY MA MD ME MI MO MS MT ND NE NJ NM PA
      RI SC SD TX VA VT WA WI WY
    ].to_set.freeze

    SUPPORTED_STATE_ID_TYPES = %w[
      drivers_license drivers_permit state_id_card
    ].to_set.freeze

    INVALID_STATE_ID_NUMBER = '00000000'

    TRANSACTION_ID = 'state-id-mock-transaction-id-456'

    proof do |applicant, result|
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
      !SUPPORTED_STATES.include? state_id_jurisdiction
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
