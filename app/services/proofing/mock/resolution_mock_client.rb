module Proofing
  module Mock
    class ResolutionMockClient < Proofing::Base
      vendor_name 'ResolutionMock'

      required_attributes :uuid,
                          :first_name,
                          :last_name,
                          :dob,
                          :ssn,
                          :address1,
                          :city,
                          :state,
                          :zipcode

      optional_attributes :address2, :uuid_prefix

      stage :resolution

      UNVERIFIABLE_ZIP_CODE = '00000'
      NO_CONTACT_SSN = /000-?00-?0000/
      TRANSACTION_ID = 'resolution-mock-transaction-id-123'
      REFERENCE = 'aaa-bbb-ccc'

      proof do |applicant, result|
        first_name = applicant[:first_name]
        ssn = applicant[:ssn]

        raise 'Failed to contact proofing vendor' if /Fail/i.match?(first_name)
        raise 'Failed to contact proofing vendor' if ssn.match?(NO_CONTACT_SSN)

        if first_name.match?(/Bad/i)
          result.add_error(:first_name, 'Unverified first name.')

        elsif first_name.match?(/Time/i)
          raise Proofing::TimeoutError, 'resolution mock timeout'

        elsif !verified_ssn?(ssn)
          result.add_error(:ssn, 'Unverified SSN.')

        elsif applicant[:zipcode] == UNVERIFIABLE_ZIP_CODE
          result.add_error(:zipcode, 'Unverified ZIP code.')
        end

        result.transaction_id = TRANSACTION_ID
        result.reference = REFERENCE
      end

      # To reduce the chances of allowing real PII in the mock proofer, we only allow SSNs that
      # start with 900 or 666 or appear in the configurable allow list
      def verified_ssn?(ssn)
        ssn.start_with?('900', '666') ||
          IdentityConfig.store.test_ssn_allowed_list.include?(ssn.delete('-'))
      end
    end
  end
end
