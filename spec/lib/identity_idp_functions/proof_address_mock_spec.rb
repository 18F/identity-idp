require 'rails_helper'
require 'identity_idp_functions/proof_address_mock'

RSpec.describe IdentityIdpFunctions::ProofAddressMock do
  let(:transaction_id) { IdentityIdpFunctions::AddressMockClient::TRANSACTION_ID }
  let(:logger) { Logger.new('/dev/null') }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: '18888675309',
    }
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofAddressMock.new(
        applicant_pii: applicant_pii,
        logger: logger,
      )
    end

    context 'with a successful response from the proofer' do
      it 'returns a result' do
        expect(function.proof).to eq(
          address_result: {
            exception: nil,
            errors: {},
            messages: [],
            success: true,
            timed_out: false,
            transaction_id: transaction_id,
            context: { stages: [
              { address: 'AddressMock' },
            ] },
          },
        )
      end
    end

    context 'with an unsuccessful response from the proofer' do
      let(:applicant_pii) do
        super().merge(
          phone: IdentityIdpFunctions::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER,
        )
      end

      it 'returns a result' do
        result = function.proof

        expect(result[:address_result][:success]).to eq(false)
      end
    end
  end
end
