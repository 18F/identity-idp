require 'rails_helper'

RSpec.describe Proofing::Mock::DdpMockClient do
  around do |ex|
    REDIS_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_POOL.with { |client| client.flushdb }
  end

  let(:threatmetrix_session_id) { SecureRandom.uuid }

  let(:applicant) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
      threatmetrix_session_id:,
      request_ip: Faker::Internet.ip_v4_address,
    )
  end

  subject(:instance) { described_class.new }

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

      it 'has an exception result' do
        expect(result.review_status).to be_nil
        expect(result.response_body).to be_nil
        expect(result.exception.inspect).to include('Unexpected ThreatMetrix review_status value')
        expect(result.success?).to eq(false)
      end
    end

    context 'with reject' do
      let(:redis_result) { 'reject' }

      it 'has a reject status' do
        expect(result.review_status).to eq('reject')
        expect(result.response_body['review_status']).to eq('reject')
      end
      it 'has an error on result' do
        expect(result.errors).to eql(review_status: ['reject'])
      end
    end

    context 'with review' do
      let(:redis_result) { 'review' }

      it 'has a review status' do
        expect(result.review_status).to eq('review')
        expect(result.response_body['review_status']).to eq('review')
      end

      it 'has an error on result' do
        expect(result.errors).to eql(review_status: ['review'])
      end
    end

    context 'with pass' do
      let(:redis_result) { 'pass' }

      it 'has a pass status' do
        expect(result.review_status).to eq('pass')
        expect(result.response_body['review_status']).to eq('pass')
      end
      it 'does not have an error on result' do
        expect(result.errors).to eql({})
      end
    end

    context 'with failed request' do
      let(:redis_result) { 'pass' }

      subject(:instance) { described_class.new response_fixture_file: 'error_response.json' }

      it 'records request error' do
        expect(result.errors).to eql({ request_result: ['fail_invalid_parameter'] })
      end
    end
  end
end
