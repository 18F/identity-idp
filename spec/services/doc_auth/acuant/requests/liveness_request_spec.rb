require 'rails_helper'

RSpec.describe DocAuth::Acuant::Requests::LivenessRequest do
  describe '#fetch' do
    let(:url) do
      URI.join(passlive_url, '/api/v1/liveness')
    end
    let(:request_body) do
      {
        'Settings' => {
          'SubscriptionId' => assure_id_subscription_id,
          'AdditionalSettings' => { 'OS' => 'UNKNOWN' },
        },
        'Image' => Base64.strict_encode64(DocAuthImageFixtures.selfie_image),
      }.to_json
    end

    let(:passlive_url) { 'https://acuant.passlive.example.com' }
    let(:assure_id_subscription_id) { '1234567' }

    let(:config) do
      DocAuth::Acuant::Config.new(
        passlive_url: passlive_url,
        assure_id_subscription_id: assure_id_subscription_id,
      )
    end

    subject(:request) do
      described_class.new(config: config, image: DocAuthImageFixtures.selfie_image)
    end

    context 'when the request is successful' do
      let(:response_body) { AcuantFixtures.liveness_response_success }

      it 'returns a successful response' do
        request_stub = stub_request(:post, url).
          with(body: request_body).
          to_return(body: response_body)

        response = request.fetch

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to be_nil
        expect(request_stub).to have_been_requested
      end
    end

    context 'when the request is unsuccessful' do
      let(:response_body) { AcuantFixtures.liveness_response_failure }

      it 'returns an unsuccessful response' do
        request_stub = stub_request(:post, url).
          with(body: request_body).
          to_return(body: response_body)

        response = request.fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(selfie: true)
        expect(response.exception).to be_nil
        expect(request_stub).to have_been_requested
      end
    end
  end
end
