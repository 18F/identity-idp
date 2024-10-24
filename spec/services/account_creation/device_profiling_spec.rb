require 'rails_helper'

RSpec.describe AccountCreation::DeviceProfiling do
  let(:current_sp) { build(:service_provider) }
  let(:threatmetrix_session_id) { '13232' }
  let(:threatmetrix_proofer_result) do
    instance_double(Proofing::DdpResult, success?: true, transaction_id: 'ddp-123')
  end
  let(:threatmetrix_proofer) do
    instance_double(
      Proofing::LexisNexis::Ddp::Proofer,
      proof: threatmetrix_proofer_result,
    )
  end

  subject(:device_profiling) { described_class.new }

  describe '#proof' do
    subject(:proof) do
    end

    before do
      allow(device_profiling).to receive(:proofer).and_return(threatmetrix_proofer)
    end

    context 'ThreatMetrix is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_creation_device_profiling).
          and_return(:collect_only)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled).
          and_return(false)

        @device_profiling_result = device_profiling.proof(
          request_ip: Faker::Internet.ip_v4_address,
          threatmetrix_session_id: threatmetrix_session_id,
          user_email: Faker::Internet.email,
          current_sp: current_sp,
        )
      end

      context 'session id is missing' do
        let(:threatmetrix_session_id) { nil }

        it 'does not make a request to the ThreatMetrix proofer' do
          expect(threatmetrix_proofer).not_to have_received(:proof)
        end

        it 'returns a failed result' do
          expect(@device_profiling_result.success?).to be(false)
          expect(@device_profiling_result.client).to eq('tmx_session_id_missing')
          expect(@device_profiling_result.review_status).to eq('reject')
        end
      end

      context 'valid threatmetrix input' do
        it 'makes a request to the ThreatMetrix proofer' do
          expect(threatmetrix_proofer).to have_received(:proof)
        end

        it 'returns a passed result' do
          expect(@device_profiling_result.success?).to be(true)
          expect(@device_profiling_result.transaction_id).to eq('ddp-123')
        end
      end
    end
  end
end
