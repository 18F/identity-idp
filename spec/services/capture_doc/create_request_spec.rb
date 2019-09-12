require 'rails_helper'

describe CaptureDoc::CreateRequest do
  let(:subject) { described_class }
  let(:user_id) { 1 }
  let(:old_timestamp) { Time.zone.now - 1.year }

  it 'creates a new request if one does not exist' do
    result = subject.call(user_id)
    expect(result).to be_kind_of(DocCapture)

    doc_capture = DocCapture.find_by(user_id: user_id)

    expect(doc_capture.request_token).to be_present
    expect(doc_capture.requested_at).to be_present
    expect(doc_capture.acuant_token).to be_nil
  end

  it 'update a request if one already exists' do
    DocCapture.create(user_id: user_id, request_token: 'foo', requested_at: old_timestamp)

    result = subject.call(user_id)
    expect(result).to be_kind_of(DocCapture)

    doc_capture = DocCapture.find_by(user_id: user_id)
    expect(doc_capture.request_token).to be_present
    expect(doc_capture.request_token).to_not eq('foo')
    expect(doc_capture.request_token).to be_present
    expect(doc_capture.requested_at).to_not eq(old_timestamp)
    expect(doc_capture.acuant_token).to be_nil
  end
end
