require 'rails_helper'

describe CaptureDoc::CreateRequest do
  let(:subject) { described_class }
  let(:user_id) { 1 }
  let(:old_timestamp) { Time.zone.now - 1.year }

  it 'creates a new request if one does not exist' do
    subject.call(user_id)

    dc = DocCapture.find_by(user_id: user_id)

    expect(dc.request_token).to be_present
    expect(dc.requested_at).to be_present
  end

  it 'update a request if one already exists' do
    DocCapture.create(user_id: user_id, request_token: 'foo', requested_at: old_timestamp)

    subject.call(user_id)

    dc = DocCapture.find_by(user_id: user_id)
    expect(dc.request_token).to be_present
    expect(dc.request_token).to_not eq('foo')
    expect(dc.request_token).to be_present
    expect(dc.requested_at).to_not eq(old_timestamp)
  end
end
