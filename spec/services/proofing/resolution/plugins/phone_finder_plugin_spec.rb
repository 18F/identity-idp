require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::PhoneFinderPlugin do
  let(:applicant_pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(uuid_prefix: '123', uuid: 'abc')
  end
  let(:current_sp) { build(:service_provider) }
  let(:ipp_enrollment_in_progress) { false }
  let(:timer) { JobHelpers::Timer.new }

  let(:state_id_address_resolution_result) do
    Proofing::Resolution::Result.new(success: true, vendor_name: 'lexisnexis:instant_verify')
  end
  let(:residential_address_resolution_result) do
    Proofing::Resolution::Result.new(success: true, vendor_name: 'lexisnexis:instant_verify')
  end
  let(:state_id_result) do
    Proofing::Resolution::Result.new(success: true, vendor_name: 'aamva:state_id')
  end

  subject(:plugin) { described_class.new }

  describe '#call' do
    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        state_id_address_resolution_result:,
        residential_address_resolution_result:,
        state_id_result:,
        ipp_enrollment_in_progress:,
        timer:,
      )
    end

    def sp_cost_count_with_transaction_id
      SpCost.where(
        cost_type: :lexis_nexis_address,
        issuer: current_sp.issuer,
        transaction_id: 'address-mock-transaction-id-123',
      ).count
    end

    context 'unsupervised remote proofing' do
      it 'returns an unsuccessful result if any upstream results are unsuccessful' do
        failed_upstream_vendor_result = Proofing::Resolution::Result.new(
          success: false,
          vendor_name: 'vendor:test',
        )
        default_plugin_arguments = {
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          residential_address_resolution_result:,
          state_id_result:,
          ipp_enrollment_in_progress:,
          timer:,
        }

        state_id_address_failed_result = plugin.call(
          **default_plugin_arguments,
          state_id_address_resolution_result: failed_upstream_vendor_result,
        )
        expect(state_id_address_failed_result.success?).to eq(false)
        expect(state_id_address_failed_result.vendor_name).to eq('ResolutionCannotPass')

        residential_address_failed_result = plugin.call(
          **default_plugin_arguments,
          residential_address_resolution_result: failed_upstream_vendor_result,
        )
        expect(residential_address_failed_result.success?).to eq(false)
        expect(residential_address_failed_result.vendor_name).to eq('ResolutionCannotPass')

        state_id_failed_result = plugin.call(
          **default_plugin_arguments,
          state_id_result: failed_upstream_vendor_result,
        )
        expect(state_id_failed_result.success?).to eq(false)
        expect(state_id_failed_result.vendor_name).to eq('ResolutionCannotPass')
      end

      context 'there is no phone number in the applicant' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

        it 'returns an unsuccessful result' do
          result = call

          expect(result.success?).to eq(false)
          expect(result.vendor_name).to eq('NoPhoneNumberAvailable')
        end
      end

      context 'the applicant has a phone number' do
        it 'calls the proofer and returns the results' do
          expect(plugin.proofer).to receive(:proof).with(
            {
              uuid: 'abc',
              uuid_prefix: '123',
              first_name: 'FAKEY',
              last_name: 'MCFAKERSON',
              ssn: '900-66-1234',
              dob: '1938-10-06',
              phone: '12025551212',
            },
          ).and_call_original

          result = call

          expect(result.success?).to eq(true)
          expect(result.vendor_name).to eq('AddressMock')
        end

        it 'records an SP cost' do
          expect do
            call
          end.to(change { sp_cost_count_with_transaction_id }.by(1))
        end

        context 'the transaction raises an error' do
          let(:applicant_pii) do
            super().merge(phone: Proofing::Mock::AddressMockClient::FAILED_TO_CONTACT_PHONE_NUMBER)
          end

          it 'returns an unsuccessful result' do
            result = call

            expect(result.success?).to eq(false)
            expect(result.exception).to be_present
          end

          it 'does not record an SP cost' do
            expect do
              call
            end.to_not(change { sp_cost_count_with_transaction_id })
          end
        end
      end
    end

    context 'in-person proofing' do
      let(:ipp_enrollment_in_progress) { true }

      it 'returns an unsuccessful result' do
        result = call

        expect(result.success?).to eq(false)
        expect(result.vendor_name).to eq('PhoneIgnoredForInPersonProofing')
      end
    end
  end
end
