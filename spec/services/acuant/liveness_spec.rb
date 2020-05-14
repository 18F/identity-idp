require 'rails_helper'

describe Acuant::Liveness do
  subject { described_class.new }
  let(:image_data) { 'live-selfie' }
  let(:good_liveness_result) do
    [true, { 'LivenessResult': { 'Score': 99, 'LivenessAssessment': 'Live' }, 'Error': nil,
             'ErrorCode': nil, 'TransactionId': '4a11ceed-7a54-45fa-9528-3945b51a1e23' }.to_json]
  end
  let(:good_faceimage_result) do
    [true, 'license-image']
  end
  let(:good_facematch_result) do
    [true, { IsMatch: true }.to_json]
  end

  before do
    allow(Figaro.env).to receive(:acuant_simulator).and_return('false')
    allow(Rails.env).to receive(:test?).and_return(false)
  end

  it 'determines the photo is live and also matches the face on the license' do
    allow_any_instance_of(Idv::Acuant::Liveness).to receive(:liveness).
      and_return(good_liveness_result)
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:face_image).
      and_return(good_faceimage_result)
    allow_any_instance_of(Idv::Acuant::FacialMatch).to receive(:facematch).
      and_return(good_facematch_result)
    result = subject.call(image_data)

    expect(result).to eq([true, nil])
  end
end
