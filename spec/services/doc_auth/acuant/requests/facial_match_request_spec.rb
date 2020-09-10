require 'rails_helper'

describe DocAuth::Acuant::Requests::FacialMatchRequest do
  describe '#fetch' do
    let(:url) do
      URI.join(Figaro.env.acuant_facial_match_url, '/api/v1/facematch')
    end
    let(:request_body) do
      {
        'Data': {
          'ImageOne': Base64.strict_encode64(DocAuthImageFixtures.selfie_image),
          'ImageTwo': Base64.strict_encode64(DocAuthImageFixtures.document_face_image),
        },
        'Settings': {
          'SubscriptionId': Figaro.env.acuant_assure_id_subscription_id,
        },
      }.to_json
    end

    context 'when the request is successful' do
      let(:response_body) { AcuantFixtures.facial_match_response_success }

      it 'returns a successful response' do
        request_stub = stub_request(:post, url).
                       with(body: request_body).
                       to_return(body: response_body)

        response = described_class.new(
          selfie_image: DocAuthImageFixtures.selfie_image,
          document_face_image: DocAuthImageFixtures.document_face_image,
        ).fetch

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to be_nil
        expect(request_stub).to have_been_requested
      end
    end

    context 'when the request is unsuccessful' do
      let(:response_body) { AcuantFixtures.facial_match_response_failure }

      it 'returns an unsuccessful response' do
        request_stub = stub_request(:post, url).
                       with(body: request_body).
                       to_return(body: response_body)

        response = described_class.new(
          selfie_image: DocAuthImageFixtures.selfie_image,
          document_face_image: DocAuthImageFixtures.document_face_image,
        ).fetch

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(selfie: I18n.t('errors.doc_auth.selfie'))
        expect(response.exception).to be_nil
        expect(request_stub).to have_been_requested
      end
    end
  end
end
