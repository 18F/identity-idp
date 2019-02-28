require 'rails_helper'

describe CaptureDoc::UpdateAcuantToken do
  let(:subject) { described_class }
  let(:user_id) { 1 }
  let(:old_timestamp) { Time.zone.now - 1.year }
  let(:token) { 'foo' }

  it 'updates the token if the entry exists' do
    CaptureDoc::CreateRequest.call(user_id)

    subject.call(user_id, token)
    expect(DocCapture.count).to eq(1)
    expect(DocCapture.find_by(user_id).acuant_token).to eq(token)
  end

  it 'does not create an entry if one does not exist' do
    subject.call(user_id, token)

    expect(DocCapture.count).to eq(0)
  end
end
