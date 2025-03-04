require 'rails_helper'

RSpec.describe AccountCreation::DeviceProfiling do
  let(:threatmetrix_session_id) { '13232' }
  let(:threatmetrix_proofer_result) do
    instance_double(Proofing::DdpResult, success?: true, transaction_id: 'ddp-123')
  end
  let(:service_provider) { create(:service_provider) }
  let(:threatmetrix_proofer) do
    instance_double(
      Proofing::LexisNexis::Ddp::Proofer,
      proof: threatmetrix_proofer_result,
    )
  end
  let(:user) { create(:user) }

  subject(:device_profiling) { described_class.new }

  describe '#proof' do
    before do
      allow(device_profiling).to receive(:proofer).and_return(threatmetrix_proofer)
    end

    subject(:result) do
      device_profiling.proof(
        request_ip: Faker::Internet.ip_v4_address,
        threatmetrix_session_id: threatmetrix_session_id,
        user_email: user.email_addresses.take.email,
        uuid_prefix: service_provider.app_id,
        uuid: user.uuid,
        workflow: workflow,
      )
    end

    context 'ThreatMetrix is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_creation_device_profiling)
          .and_return(:collect_only)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(false)
      end

      context 'session id is missing' do
        let(:threatmetrix_session_id) { nil }

        it 'does not make a request to the ThreatMetrix proofer' do
          result
          expect(threatmetrix_proofer).not_to have_received(:proof)
        end

        it 'returns a failed result' do
          expect(result.success?).to be(false)
          expect(result.client).to eq('tmx_session_id_missing')
          expect(result.review_status).to eq('reject')
        end
      end

      context 'valid threatmetrix input' do
        it 'makes a request to the ThreatMetrix proofer' do
          result
          expect(threatmetrix_proofer).to have_received(:proof)
        end

        it 'returns a passed result' do
          expect(result.success?).to be(true)
          expect(result.transaction_id).to eq('ddp-123')
        end
      end
    end
  end
end
