require 'rails_helper'

describe DocAuth::Acuant::Responses::LivenessResponse do
  context 'when the response is successful' do
    it 'returns a successful resposne with no errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.liveness_response_success,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: true,
        errors: {},
        exception: nil,
        liveness_assessment: 'Live',
        liveness_score: 99,
        acuant_error: { message: nil, code: nil },
      )
    end
  end

  context 'when the response fails' do
    it 'returns a unsuccessful response with errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.liveness_response_failure,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(false)
      expect(response.errors).to eq(selfie: I18n.t('errors.doc_auth.selfie'))
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: false,
        errors: { selfie: I18n.t('errors.doc_auth.selfie') },
        exception: nil,
        liveness_assessment: nil,
        liveness_score: nil,
        acuant_error: {
          message: 'Face is too small. Move the camera closer to the face and retake the picture.',
          code: 'FaceTooSmall',
        },
      )
    end
  end
end
