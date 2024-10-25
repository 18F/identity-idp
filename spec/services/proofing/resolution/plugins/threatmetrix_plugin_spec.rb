require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::ThreatMetrixPlugin do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }

  let(:current_sp) { build(:service_provider) }

  let(:proofer_result) do
    instance_double(Proofing::DdpResult, success?: true, transaction_id: 'ddp-123')
  end

  let(:request_ip) { Faker::Internet.ip_v4_address }

  let(:user_email) { Faker::Internet.email }

  let(:threatmetrix_session_id) { 'cool-session-id' }

  subject(:plugin) do
    described_class.new
  end

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled).
      and_return(false)
    allow(plugin.proofer).to receive(:proof).and_return(proofer_result)
  end

  describe '#call' do
    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        request_ip:,
        threatmetrix_session_id:,
        timer: JobHelpers::Timer.new,
        user_email:,
      )
    end

    context 'ThreatMetrix is enabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
          and_return(true)
      end

      it 'makes a request to the ThreatMetrix proofer' do
        call
        expect(plugin.proofer).to have_received(:proof)
      end

      it 'creates a ThreatMetrix associated cost' do
        expect { call }.
          to change {
               SpCost.where(cost_type: :threatmetrix, issuer: current_sp.issuer).count
             }.to eql(1)
      end

      context 'session id is missing' do
        let(:threatmetrix_session_id) { nil }

        it 'does not make a request to the ThreatMetrix proofer' do
          expect(plugin.proofer).not_to have_received(:proof)
        end

        it 'returns a failed result' do
          result = call
          expect(result.success).to be(false)
          expect(result.client).to eq('tmx_session_id_missing')
          expect(result.review_status).to eq('reject')
        end
      end

      context 'pii is missing' do
        let(:applicant_pii) { {} }

        it 'does not make a request to the ThreatMetrix proofer' do
          call
          expect(plugin.proofer).not_to have_received(:proof)
        end

        it 'returns a failed result' do
          result = call

          expect(result.success).to be(false)
          expect(result.client).to eq('tmx_pii_missing')
          expect(result.review_status).to eq('reject')
        end
      end
    end

    context 'ThreatMetrix is disabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
          and_return(false)
      end

      it 'returns a disabled result' do
        result = call

        expect(result.success).to be(true)
        expect(result.client).to eq('tmx_disabled')
        expect(result.review_status).to eq('pass')
      end

      it 'does not create a ThreatMetrix associated cost' do
        expect { call }.
          not_to change {
                   SpCost.where(cost_type: :threatmetrix, issuer: current_sp.issuer).count
                 }.from(0)
      end
    end
  end
end
