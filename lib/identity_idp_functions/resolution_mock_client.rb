# frozen_string_literal: true

require 'proofer'

module IdentityIdpFunctions
  class ResolutionMockClient < Proofer::Base
    vendor_name 'ResolutionMock'

    required_attributes :first_name, :ssn, :zipcode

    optional_attributes :uuid, :uuid_prefix

    stage :resolution

    UNVERIFIABLE_ZIP_CODE = '00000'
    NO_CONTACT_SSN = '000-00-0000'
    TRANSACTION_ID = 'resolution-mock-transaction-id-123'

    proof do |applicant, result|
      first_name = applicant[:first_name]
      ssn = applicant[:ssn]

      raise 'Failed to contact proofing vendor' if first_name =~ /Fail/i
      raise 'Failed to contact proofing vendor' if ssn == NO_CONTACT_SSN

      if first_name.match?(/Bad/i)
        result.add_error(:first_name, 'Unverified first name.')

      elsif first_name.match?(/Time/i)
        raise Proofer::TimeoutError, 'resolution mock timeout'

      elsif applicant[:ssn].match?(/6666/)
        result.add_error(:ssn, 'Unverified SSN.')

      elsif applicant[:zipcode] == UNVERIFIABLE_ZIP_CODE
        result.add_error(:zipcode, 'Unverified ZIP code.')
      end

      result.transaction_id = TRANSACTION_ID
    end
  end
end
