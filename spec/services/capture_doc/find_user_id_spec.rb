require 'rails_helper'

describe CaptureDoc::FindUserId do
  let(:subject) { described_class }
  let(:user_id) { 1 }

  it 'finds the user_id if it exists and is not expired' do
    doc_capture = CaptureDoc::CreateRequest.call(user_id)
    result = subject.call(doc_capture.request_token)

    expect(result).to eq(user_id)
  end

  it 'does not find the user_id if it the token is expired' do
    doc_capture = nil
    Timecop.travel(Time.zone.now - 1.day) do
      doc_capture = CaptureDoc::CreateRequest.call(user_id)
    end

    result = subject.call(doc_capture.request_token)
    expect(result).to eq(nil)
  end

  it 'does not find the user_id if there is no request' do
    result = subject.call('foo')
    expect(result).to eq(nil)
  end
end
