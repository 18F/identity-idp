require 'rails_helper'

describe DocAuth::Acuant::Responses::GetFaceImageResponse do
  it 'contains the face image from the response' do
    http_response = instance_double(
      Faraday::Response,
      body: AcuantFixtures.get_face_image_response,
    )

    response = described_class.new(http_response)

    expect(response.success?).to eq(true)
    expect(response.image).to eq(AcuantFixtures.get_face_image_response)
    expect(response.errors).to eq({})
    expect(response.exception).to be_nil
  end
end
