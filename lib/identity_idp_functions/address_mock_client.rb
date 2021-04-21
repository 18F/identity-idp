# frozen_string_literal: true

require 'proofer'

module IdentityIdpFunctions
  class AddressMockClient < Proofer::Base
    vendor_name 'AddressMock'

    required_attributes :phone

    optional_attributes :uuid, :uuid_prefix

    stage :address

    UNVERIFIABLE_PHONE_NUMBER = '7035555555'
    PROOFER_TIMEOUT_PHONE_NUMBER = '7035555888'
    FAILED_TO_CONTACT_PHONE_NUMBER = '7035555999'
    TRANSACTION_ID = 'address-mock-transaction-id-123'

    proof do |applicant, result|
      plain_phone = applicant[:phone].gsub(/\D/, '').gsub(/\A1/, '')
      if plain_phone == UNVERIFIABLE_PHONE_NUMBER
        result.add_error(:phone, 'The phone number could not be verified.')
      elsif plain_phone == FAILED_TO_CONTACT_PHONE_NUMBER
        raise 'Failed to contact proofing vendor'
      elsif plain_phone == PROOFER_TIMEOUT_PHONE_NUMBER
        raise Proofer::TimeoutError, 'address mock timeout'
      end
      result.transaction_id = TRANSACTION_ID
      result.context[:message] = 'some context for the mock address proofer'
    end
  end
end
