require 'rails_helper'

RSpec.describe Idv::Resolution::InstantVerifyPlugin do
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

  let(:input) do
    Idv::Resolution::Input.from_pii(pii)
  end

  describe '#call' do
    context 'when no state_id present' do
      let(:input) do
        Idv::Resolution::Input.from_pii(pii).with(state_id: nil)
      end

      context 'and no address_of_residence present' do
        it 'returns a failure result' do
          next_plugin = spy
          expect(next_plugin).to receive(:call).with(
            instant_verify: {
              success: false,
              reason: :no_state_id,
            },
          )
          subject.call(
            input:,
            result: {},
            next_plugin:,
          )
        end

        it 'makes no InstantVerify calls' do
          next_plugin = spy
          allow(next_plugin).to receive(:call)

          expect_any_instance_of(Proofing::Mock::ResolutionMockClient).
            not_to receive(:proof)

          subject.call(
            input:,
            result: {},
            next_plugin:,
          )
        end
      end

      context 'but address_of_residence present' do
        let(:input) do
          Idv::Resolution::Input.from_pii(pii).with(state_id: nil)
        end

        it 'makes no InstantVerify calls' do
          next_plugin = spy
          expect(next_plugin).to receive(:call).with(
            instant_verify: {
              success: false,
              reason: :no_state_id,
            },
          )
          subject.call(
            input:,
            result: {},
            next_plugin:,
          )
        end
      end
    end

    context 'when state_id.address same as address_of_residence' do
      let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

      it 'verifies the address only once' do
        next_plugin = spy
        expect(next_plugin).to receive(:call).with(
          instant_verify: {
            success: true,
            state_id_address: instance_of(Proofing::Resolution::Result),
          },
        )

        subject.call(
          input:,
          result: {},
          next_plugin:,
        )
      end
    end

    context 'when state_id.address differs from address_of_residence' do
      let(:pii) do
        Idp::Constants::MOCK_IDV_APPLICANT.merge(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS)
      end

      it 'verifies both addresses' do
        expect_any_instance_of(Proofing::Mock::ResolutionMockClient).to receive(:proof).with(
          {
            address1: '123 Way St',
            address2: '2nd Address Line',
            city: 'Best City',
            dob: '1938-10-06',
            first_name: 'FAKEY',
            last_name: 'MCFAKERSON',
            ssn: '900-66-1234',
            state: 'VA',
            zipcode: '12345',
          },
        ).and_call_original

        expect_any_instance_of(Proofing::Mock::ResolutionMockClient).to receive(:proof).with(
          {
            address1: '1 FAKE RD',
            address2: nil,
            city: 'GREAT FALLS',
            dob: '1938-10-06',
            first_name: 'FAKEY',
            last_name: 'MCFAKERSON',
            ssn: '900-66-1234',
            state: 'MT',
            zipcode: '59010',
          },
        ).and_call_original

        next_plugin = spy
        expect(next_plugin).to receive(:call).with(
          instant_verify: {
            success: true,
            state_id_address: instance_of(Proofing::Resolution::Result),
            address_of_residence: instance_of(Proofing::Resolution::Result),
          },
        )

        subject.call(
          input:,
          result: {},
          next_plugin:,
        )
      end

      context 'and address_of_residence fails verification' do
        it 'does not bother verifying state_id.address'
      end
    end
  end
end
