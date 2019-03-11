require 'rails_helper'

describe CaptureDoc::UpdateAcuantToken do
  let(:subject) { described_class }
  let(:user_id) { 1 }
  let(:token) { 'foo' }

  it 'updates the token if the entry exists' do
    CaptureDoc::CreateRequest.call(user_id)

    result = subject.call(user_id, token)
    expect(result).to be_truthy
    expect(DocCapture.count).to eq(1)
    expect(DocCapture.find_by(user_id: user_id).acuant_token).to eq(token)
  end

  it 'does not create an entry if one does not exist' do
    result = subject.call(user_id, token)
    expect(result).to be_falsey

    expect(DocCapture.count).to eq(0)
  end
end
