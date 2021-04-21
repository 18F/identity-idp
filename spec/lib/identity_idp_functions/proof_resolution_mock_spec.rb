require 'rails_helper'
require 'identity_idp_functions/proof_resolution_mock'

RSpec.describe IdentityIdpFunctions::ProofResolutionMock do
  let(:ssn) { '123456789' }
  let(:bad_ssn) { IdentityIdpFunctions::ResolutionMockClient::NO_CONTACT_SSN }
  let(:trace_id) { SecureRandom.uuid }
  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: ssn,
      zipcode: '53206',
      phone: '18888675309',
      state_id_number: '123456',
      state_id_type: 'drivers_license',
      state_id_jurisdiction: 'WI',
    }
  end
  let(:resolution_transaction_id) { IdentityIdpFunctions::ResolutionMockClient::TRANSACTION_ID }
  let(:state_id_transaction_id) { IdentityIdpFunctions::StateIdMockClient::TRANSACTION_ID }
  let(:logger) { Logger.new('/dev/null') }

  describe '#proof' do
    let(:should_proof_state_id) { true }
    let(:dob_year_only) { false }

    subject(:function) do
      IdentityIdpFunctions::ProofResolutionMock.new(
        applicant_pii: applicant_pii,
        should_proof_state_id: should_proof_state_id,
        dob_year_only: dob_year_only,
        trace_id: trace_id,
        logger: logger,
      )
    end

    it 'runs' do
      expect(function.proof).to eq(
        resolution_result: {
          exception: nil,
          errors: {},
          messages: [],
          success: true,
          timed_out: false,
          context: {
            stages: [
              { resolution: 'ResolutionMock', transaction_id: resolution_transaction_id },
              { state_id: 'StateIdMock', transaction_id: state_id_transaction_id },
            ],
          },
          transaction_id: resolution_transaction_id,
        },
      )
    end

    it 'logs the trace_id and timing info' do
      expect(logger).to receive(:info).with(hash_including(:timing, trace_id: trace_id))

      function.proof
    end

    context 'does not call state id with an unsuccessful response from the proofer' do
      let(:ssn) { bad_ssn }
      it 'posts back to the callback url' do
        function.proof
        expect_any_instance_of(IdentityIdpFunctions::StateIdMockClient).not_to receive(:proof)
      end
    end

    context 'no state_id proof' do
      let(:should_proof_state_id) { false }

      it 'does not call state_id proof if resolution proof is successful' do
        expect(function.state_id_mock_proofer).not_to receive(:proof)
        function.proof
      end
    end

    context 'with a failure response from the state id verifier' do
      let(:applicant_pii) do
        super().merge(
          state_id_number: IdentityIdpFunctions::StateIdMockClient::INVALID_STATE_ID_NUMBER,
        )
      end

      it 'is a failure response' do
        resolution_result = function.proof

        expect(resolution_result[:success]).to be_falsey
      end
    end
  end
end
