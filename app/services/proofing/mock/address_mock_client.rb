module Proofing
  module Mock
    class AddressMockClient
      UNVERIFIABLE_PHONE_NUMBER = '7035555555'
      PROOFER_TIMEOUT_PHONE_NUMBER = '7035555888'
      FAILED_TO_CONTACT_PHONE_NUMBER = '7035555999'
      TRANSACTION_ID = 'address-mock-transaction-id-123'

      AddressMockClientResult = Struct.new(:success, :errors, :exception, keyword_init: true) do
        def success?
          success
        end

        def transaction_id
          TRANSACTION_ID
        end

        def to_h
          {
            exception: exception,
            errors: errors,
            success: success,
            timed_out: exception.is_a?(Proofing::TimeoutError),
            transaction_id: transaction_id,
            vendor_name: 'AddressMock',
          }
        end
      end

      def proof(applicant)
        plain_phone = applicant[:phone].gsub(/\D/, '').delete_prefix('1')
        if plain_phone == UNVERIFIABLE_PHONE_NUMBER
          unverifiable_phone_result
        elsif plain_phone == FAILED_TO_CONTACT_PHONE_NUMBER
          failed_to_contact_vendor_result
        elsif plain_phone == PROOFER_TIMEOUT_PHONE_NUMBER
          timeout_result
        else
          AddressMockClientResult.new(success: true, errors: {}, exception: nil)
        end
      end

      private

      def unverifiable_phone_result
        AddressMockClientResult.new(
          success: false,
          errors: { phone: ['The phone number could not be verified.'] },
          exception: nil,
        )
      end

      def failed_to_contact_vendor_result
        AddressMockClientResult.new(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
        )
      end

      def timeout_result
        AddressMockClientResult.new(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new('address mock timeout'),
        )
      end
    end
  end
end
