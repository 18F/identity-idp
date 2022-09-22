module Proofing
  module Mock
    class ResolutionMockClient < Proofing::Base
      UNVERIFIABLE_ZIP_CODE = '00000'
      NO_CONTACT_SSN = /000-?00-?0000/
      TRANSACTION_ID = 'resolution-mock-transaction-id-123'
      REFERENCE = 'aaa-bbb-ccc'

      ResolutionMockClientResult = Struct.new(:success, :errors, :exception, keyword_init: true) do
        def success?
          success
        end

        def timed_out?
          exception.is_a?(Proofing::TimeoutError)
        end

        def transaction_id
          TRANSACTION_ID
        end

        def reference
          REFERENCE
        end

        def to_h
          {
            exception: exception,
            errors: errors,
            success: success,
            timed_out: timed_out?,
            transaction_id: transaction_id,
            reference: reference,
            vendor_name: 'ResolutionMock',
          }
        end

        def failed_result_can_pass_with_additional_verification?
          false
        end

        def attributes_requiring_additional_verification
          []
        end
      end

      def proof(applicant)
        first_name = applicant[:first_name]
        ssn = applicant[:ssn]
        zipcode = applicant[:zipcode]

        return failed_to_contact_vendor_result if /Fail/i.match?(first_name)
        return failed_to_contact_vendor_result if ssn.match?(NO_CONTACT_SSN)
        return timeout_result if first_name.match?(/Time/i)

        if first_name.match?(/Bad/i)
          unverifiable_result(first_name: ['Unverified first name.'])
        elsif !verified_ssn?(ssn)
          unverifiable_result(ssn: ['Unverified SSN.'])
        elsif zipcode == UNVERIFIABLE_ZIP_CODE
          unverifiable_result(zipcode: ['Unverified ZIP code.'])
        else
          ResolutionMockClientResult.new(success: true, errors: {}, exception: nil)
        end
      end

      def unverifiable_result(**errors)
        ResolutionMockClientResult.new(
          success: false,
          errors: errors,
          exception: nil,
        )
      end

      def failed_to_contact_vendor_result
        ResolutionMockClientResult.new(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
        )
      end

      def timeout_result
        ResolutionMockClientResult.new(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new('address mock timeout'),
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
