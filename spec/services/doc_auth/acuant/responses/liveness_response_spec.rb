require 'rails_helper'

RSpec.describe DocAuth::Acuant::Responses::LivenessResponse do
  context 'when the response is successful' do
    it 'returns a successful resposne with no errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.liveness_response_success,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: true,
        errors: {},
        attention_with_barcode: false,
        exception: nil,
        selfie_liveness_results: {
          liveness_assessment: 'Live',
          liveness_score: 99,
          acuant_error: { message: nil, code: nil },
        },
      )
    end
  end

  # rubocop:disable Layout/LineLength
  context 'when the response fails' do
    it 'returns a unsuccessful response with errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.liveness_response_failure,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(false)
      expect(response.errors).to eq(selfie: true)
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: false,
        errors: { selfie: true },
        attention_with_barcode: false,
        exception: nil,
        selfie_liveness_results: {
          liveness_assessment: nil,
          liveness_score: nil,
          acuant_error: {
            message: 'Face is too small. Move the camera closer to the face and retake the picture.',
            code: 'FaceTooSmall',
          },
        },
      )
    end
  end
  # rubocop:enable Layout/LineLength
end
