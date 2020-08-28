require 'rails_helper'

describe DocAuth::Acuant::Responses::FacialMatchResponse do
  context 'when the response is successful' do
    it 'returns a successful resposne with no errors' do
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
        match_score: 83,
      )
    end
  end

  context 'when the response is unsuccessful' do
    it 'returns a unsuccessful resposne with errors' do
      http_response = instance_double(
        Faraday::Response,
        body: AcuantFixtures.facial_match_response_failure,
      )

      response = described_class.new(http_response)

      expect(response.success?).to eq(false)
      expect(response.errors).to eq(selfie: I18n.t('errors.doc_auth.selfie'))
      expect(response.exception).to be_nil
      expect(response.to_h).to eq(
        success: false,
        errors: { selfie: I18n.t('errors.doc_auth.selfie') },
        exception: nil,
        match_score: 68,
      )
    end
  end
end
