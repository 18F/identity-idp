module Proofing
  module Mock
    class ResolutionMockClient < Proofing::Base
      vendor_name 'ResolutionMock'

      required_attributes :first_name, :ssn, :zipcode

      optional_attributes :uuid, :uuid_prefix

      stage :resolution

      UNVERIFIABLE_ZIP_CODE = '00000'
      NO_CONTACT_SSN = '000-00-0000'
      TRANSACTION_ID = 'resolution-mock-transaction-id-123'
      REFERENCE = 'aaa-bbb-ccc'

      proof do |applicant, result|
        first_name = applicant[:first_name]
        ssn = applicant[:ssn]

        raise 'Failed to contact proofing vendor' if /Fail/i.match?(first_name)
        raise 'Failed to contact proofing vendor' if ssn == NO_CONTACT_SSN

        if first_name.match?(/Bad/i)
          result.add_error(:first_name, 'Unverified first name.')

        elsif first_name.match?(/Time/i)
          raise Proofing::TimeoutError, 'resolution mock timeout'

        elsif !applicant[:ssn].start_with?('900')
          result.add_error(:ssn, 'Unverified SSN.')

        elsif applicant[:zipcode] == UNVERIFIABLE_ZIP_CODE
          result.add_error(:zipcode, 'Unverified ZIP code.')
        end

        result.transaction_id = TRANSACTION_ID
        result.reference = REFERENCE
      end
    end
  end
end
