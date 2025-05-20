require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::DocvResultRequest do
  let(:document_capture_session_uuid) { 'fake uuid' }
  let(:fake_analytics) { FakeAnalytics.new }

  subject(:docv_result_request) do
    described_class.new(
      document_capture_session_uuid:,
    )
  end

  describe '#fetch' do
    let(:fake_socure_endpoint) { 'https://fake-socure.test/' }
    let(:fake_socure_api_endpoint) { 'https://fake-socure.test/api/3.0/EmailAuthScore' }
    let(:docv_transaction_token) { 'fake docv transaction token' }
    let(:user) { create(:user) }
    let(:document_capture_session) do
      DocumentCaptureSession.create(user:).tap do |dcs|
        dcs.socure_docv_transaction_token = docv_transaction_token
      end
    end

    before do
      allow(IdentityConfig.store).to receive(:socure_idplus_base_url)
        .and_return(fake_socure_endpoint)
      allow(DocumentCaptureSession).to receive(:find_by).and_return(document_capture_session)
    end

    context 'with socure failures' do
      let(:status) { 'Error' }
      let(:referenceId) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
      let(:msg) { 'InternalServerException' }
      let(:fake_socure_response) { { status:, referenceId:, msg: } }
      let(:fake_socure_status) { 500 }

      it 'expect correct doc auth response during a connection failure' do
        stub_request(:post, fake_socure_api_endpoint).to_raise(Faraday::ConnectionFailed)
        response_hash = docv_result_request.fetch.to_h
        expect(response_hash[:success]).to eq(false)
        expect(response_hash[:errors]).to eq({ network: true })
        expect(response_hash[:vendor]).to eq('Socure')
        expect(response_hash[:exception]).to be_a(Faraday::ConnectionFailed)
      end

      it 'expect correct doc auth response for a socure fail response' do
        stub_request(:post, fake_socure_api_endpoint)
          .to_return(
            status: fake_socure_status,
            body: JSON.generate(fake_socure_response),
          )
        response_hash = docv_result_request.fetch.to_h
        expect(response_hash[:success]).to eq(false)
        expect(response_hash[:errors]).to eq({ network: true })
        expect(response_hash[:vendor]).to eq('Socure')
        expect(response_hash[:reference_id]).to eq(referenceId)
        expect(response_hash[:exception]).to be_a(DocAuth::RequestError)
        expect(response_hash[:exception].message).to include('Unexpected HTTP response 500')
      end
    end
  end
end
