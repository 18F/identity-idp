# frozen_string_literal: true

module Proofing
  module Mock
    class ResolutionMockClient
      UNVERIFIABLE_ZIP_CODE = '00000'
      NO_CONTACT_SSN = /000-?00-?0000/
      TRANSACTION_ID = 'resolution-mock-transaction-id-123'
      REFERENCE = 'aaa-bbb-ccc'

      def proof(applicant)
        first_name = applicant[:first_name]
        ssn = applicant[:ssn]
        zipcode = applicant[:zipcode]

        return failed_to_contact_vendor_result if ssn.match?(NO_CONTACT_SSN)
        case first_name
        when /Fail/i then return failed_to_contact_vendor_result
        when /Time/i then return timeout_result
        when /Parse/i then return parse_error_result
        when /Bad/i then return unverifiable_result(first_name: ['Unverified first name.'])
        end

        if !verified_ssn?(ssn)
          unverifiable_result(ssn: ['Unverified SSN.'])
        elsif zipcode == UNVERIFIABLE_ZIP_CODE
          unverifiable_result(zipcode: ['Unverified ZIP code.'])
        else
          resolution_result(success: true, errors: {}, exception: nil)
        end
      end

      def unverifiable_result(**errors)
        resolution_result(
          success: false,
          errors: errors,
          exception: nil,
        )
      end

      def failed_to_contact_vendor_result
        resolution_result(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
        )
      end

      def timeout_result
        resolution_result(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new('resolution mock timeout'),
        )
      end

      def parse_error_result
        resolution_result(
          success: false,
          errors: {},
          exception: Proofing::Aamva::VerificationError.new(
            'Unexpected status code in response: 504',
          ),
        )
      end

      def resolution_result(success:, errors:, exception:)
        Resolution::Result.new(
          success: success,
          errors: errors,
          exception: exception,
          transaction_id: TRANSACTION_ID,
          reference: REFERENCE,
          vendor_name: 'ResolutionMock',
        )
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
