require 'rails_helper'

RSpec.describe Proofing::Mock::DdpMockClient do
  around do |ex|
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
    ex.run
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
  end

  let(:threatmetrix_session_id) { SecureRandom.uuid }

  let(:applicant) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: Faker::Internet.ip_v4_address,
    )
  end

  subject(:instance) { described_class.new }

  it_behaves_like_mock_proofer(
    mock_proofer_class: Proofing::Mock::DdpMockClient,
    real_proofer_class: Proofing::LexisNexis::Ddp::Proofer,
  )

  describe '#proof' do
    subject(:result) { instance.proof(applicant) }

    before do
      Proofing::Mock::DeviceProfilingBackend.new.record_profiling_result(
        result: redis_result,
        session_id: threatmetrix_session_id,
      )
    end

    context 'with explicit no_result' do
      let(:redis_result) { 'no_result' }

      it 'has a nil review status' do
        expect(result.review_status).to be_nil
        expect(result.response_body['review_status']).to be_nil
      end
    end

    context 'with reject' do
      let(:redis_result) { 'reject' }

      it 'has a reject status' do
        expect(result.review_status).to eq('reject')
        expect(result.response_body['review_status']).to eq('reject')
      end
    end

    context 'with pass' do
      let(:redis_result) { 'pass' }

      it 'has a pass status' do
        expect(result.review_status).to eq('pass')
        expect(result.response_body['review_status']).to eq('pass')
      end
    end
  end
end
