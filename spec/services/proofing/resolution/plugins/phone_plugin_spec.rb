require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::PhonePlugin do
  let(:idv_phone_precheck_enabled) { true }
  let(:user) { create(:user) }
  let(:applicant_pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(uuid_prefix: '123', uuid: user.uuid)
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

  before do
    allow(IdentityConfig.store).to receive(:idv_phone_precheck_enabled)
      .and_return(idv_phone_precheck_enabled)
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
        timer:,
        user_email: user.email,
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
          timer:,
          user_email: user.email,
        }

        state_id_address_failed_result = plugin.call(
          **default_plugin_arguments,
          state_id_address_resolution_result: failed_upstream_vendor_result,
        )
        expect(state_id_address_failed_result[:success]).to eq(false)
        expect(state_id_address_failed_result[:vendor_name]).to eq('ResolutionCannotPass')

        residential_address_failed_result = plugin.call(
          **default_plugin_arguments,
          residential_address_resolution_result: failed_upstream_vendor_result,
        )
        expect(residential_address_failed_result[:success]).to eq(false)
        expect(residential_address_failed_result[:vendor_name]).to eq('ResolutionCannotPass')

        state_id_failed_result = plugin.call(
          **default_plugin_arguments,
          state_id_result: failed_upstream_vendor_result,
        )
        expect(state_id_failed_result[:success]).to eq(false)
        expect(state_id_failed_result[:vendor_name]).to eq('ResolutionCannotPass')
      end

      context 'there is no phone number in the applicant' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup }

        it 'returns an unsuccessful result' do
          result = call

          expect(result[:success]).to eq(false)
          expect(result[:vendor_name]).to eq('NoPhoneNumberAvailable')
        end
      end

      context 'the applicant has a phone number' do
        it 'calls the proofer and returns the results' do
          expect_any_instance_of(Proofing::AddressProofer).to receive(:proof).with(
            applicant_pii: {
              uuid: user.uuid,
              uuid_prefix: '123',
              first_name: 'FAKEY',
              last_name: 'MCFAKERSON',
              ssn: '900661234',
              dob: '1938-10-06',
              phone: '12025551212',
            },
            current_sp:,
          ).and_call_original

          result = call

          expect(result[:success]).to eq(true)
          expect(result[:vendor_name]).to eq('AddressMock')
        end

        it 'records an SP cost' do
          expect do
            call
          end.to(change { sp_cost_count_with_transaction_id }.by(0))
        end

        context 'the transaction raises an error' do
          let(:applicant_pii) do
            super().merge(phone: Proofing::Mock::AddressMockClient::FAILED_TO_CONTACT_PHONE_NUMBER)
          end

          it 'returns an unsuccessful result' do
            result = call

            expect(result[:success]).to eq(false)
            expect(result[:exception]).to be_present
          end

          it 'does not record an SP cost' do
            expect do
              call
            end.to_not(change { sp_cost_count_with_transaction_id })
          end
        end

        context 'when phone precheck is not enabled' do
          let(:idv_phone_precheck_enabled) { false }
          it 'does not call proofer and returns empty results' do
            expect(Proofing::AddressProofer).not_to receive(:new)
            result = call

            expect(result).to be_empty
          end
        end
      end

      context 'when service returns weird HTTP 500 response' do
        before do
          allow(IdentityConfig.store).to receive(:idv_address_primary_vendor).and_return(:socure)
          stub_request(:post, 'https://sandbox.socure.test/api/3.0/EmailAuthScore')
            .to_return(
              status: 500,
              body: 'It works!',
            )
        end

        it 'returns an unsuccessful result' do
          result = call

          expect(result[:success]).to eq(false)
          expect(result[:exception]).not_to be_nil
        end
      end

      context 'when Faraday error' do
        before do
          allow(IdentityConfig.store).to receive(:idv_address_primary_vendor).and_return(:socure)
          allow_any_instance_of(Faraday::Connection).to receive(:post)
            .and_raise(Faraday::ConnectionFailed)
        end

        it 'returns an unsuccessful result' do
          result = call

          expect(result[:success]).to eq(false)
          expect(result[:exception]).not_to be_nil
        end
      end
    end
  end
end
