module Proofing
  module Mock
    class AddressMockClient
      UNVERIFIABLE_PHONE_NUMBER = '7035555555'
      PROOFER_TIMEOUT_PHONE_NUMBER = '7035555888'
      FAILED_TO_CONTACT_PHONE_NUMBER = '7035555999'
      TRANSACTION_ID = 'address-mock-transaction-id-123'

      def proof(applicant)
        plain_phone = applicant[:phone].gsub(/\D/, '').delete_prefix('1')
        if plain_phone == UNVERIFIABLE_PHONE_NUMBER
          unverifiable_phone_result
        elsif plain_phone == FAILED_TO_CONTACT_PHONE_NUMBER
          failed_to_contact_vendor_result
        elsif plain_phone == PROOFER_TIMEOUT_PHONE_NUMBER
          timeout_result
        else
          address_result(success: true, errors: {}, exception: nil)
        end
      end

      private

      def unverifiable_phone_result
        address_result(
          success: false,
          errors: { phone: ['The phone number could not be verified.'] },
          exception: nil,
        )
      end

      def failed_to_contact_vendor_result
        address_result(
          success: false,
          errors: {},
          exception: RuntimeError.new('Failed to contact proofing vendor'),
        )
      end

      def timeout_result
        address_result(
          success: false,
          errors: {},
          exception: Proofing::TimeoutError.new('address mock timeout'),
        )
      end

      def address_result(success:, errors:, exception:)
        AddressResult.new(
          success: success,
          errors: errors,
          exception: exception,
          transaction_id: TRANSACTION_ID,
          vendor_name: 'AddressMock',
        )
      end
    end
  end
end
