require 'rails_helper'

RSpec.describe DocAuth::Acuant::Responses::FacialMatchResponse do
  context 'when the response is successful' do
    it 'returns a successful response with no errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.facial_match_response_success,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: true,
        errors: {},
        exception: nil,
        attention_with_barcode: false,
        face_match_results: {
          match_score: 83,
          is_match: true,
        },
      )
    end
  end

  context 'when the response is unsuccessful' do
    it 'returns a unsuccessful response with errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.facial_match_response_failure,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(false)
      expect(response.errors).to eq(selfie: true)
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: false,
        errors: { selfie: true },
        exception: nil,
        attention_with_barcode: false,
        face_match_results: {
          match_score: 68,
          is_match: false,
        },
      )
    end
  end
end
