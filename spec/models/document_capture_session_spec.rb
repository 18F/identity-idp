require 'rails_helper'

describe DocumentCaptureSession do
  let(:fake_analytics) { FakeAnalytics.new }
  let(:user) { create(:user, :signed_up) }
  let(:doc_auth_response) do
    DocAuth::Response.new(
      success: true,
      pii_from_doc: {
        first_name: 'Testy',
        last_name: 'Testerson',
      },
    )
  end

  describe '#store_result_from_response' do
    it 'generates a result ID stores the result encrypted in redis' do
      record = DocumentCaptureSession.new

      record.store_result_from_response(doc_auth_response)

      result_id = record.result_id
      key = EncryptedRedisStructStorage.key(result_id, type: DocumentCaptureSessionResult)
      data = READTHIS_POOL.with { |client| client.read(key) }
      expect(data).to be_a(String)
      expect(data).to_not include('Testy')
      expect(data).to_not include('Testerson')
    end
  end

  describe '#load_result' do
    it 'loads the previously stored result' do
      record = DocumentCaptureSession.new
      record.store_result_from_response(doc_auth_response)
      result = record.load_result

      expect(result.success?).to eq(doc_auth_response.success?)
      expect(result.pii).to eq(doc_auth_response.pii_from_doc.deep_symbolize_keys)
    end

    it 'returns nil if the previously stored result does not exist or expired' do
      record = DocumentCaptureSession.new
      result = record.load_result

      expect(result).to eq(nil)
    end
  end

  describe '#expired?' do
    before do
      allow(IdentityConfig.store).to receive(:doc_capture_request_valid_for_minutes).and_return(15)
    end

    context 'requested_at is nil' do
      it 'returns true' do
        record = DocumentCaptureSession.new

        expect(record.expired?).to eq(true)
      end
    end

    context 'requested_at is datetime' do
      it 'returns true if expired' do
        record = DocumentCaptureSession.new(requested_at: 1.hour.ago)

        expect(record.expired?).to eq(true)
      end

      it 'returns false if not expired' do
        record = DocumentCaptureSession.new(requested_at: 1.minute.ago)

        expect(record.expired?).to eq(false)
      end
    end
  end

  describe '.create_by_user_id' do
    it 'triggers an analytics event if an attempt is made to try to overwrite a session in use' do
      DocumentCaptureSession.create_by_user_id(user.id, fake_analytics)
      DocumentCaptureSession.create_by_user_id(user.id, fake_analytics)
      expect(fake_analytics).
        to have_logged_event(Analytics::DOCUMENT_CAPTURE_SESSION_OVERWRITTEN, {})
    end

    it 'does not trigger an analytics event upon first use' do
      DocumentCaptureSession.create_by_user_id(user.id, fake_analytics)
      expect(fake_analytics).
        to_not have_logged_event(Analytics::DOCUMENT_CAPTURE_SESSION_OVERWRITTEN, {})
    end

    it 'does not trigger an analytics event upon reuse' do
      session = DocumentCaptureSession.create_by_user_id(user.id, fake_analytics)
      session.result_id = 'foo'
      session.save!
      DocumentCaptureSession.create_by_user_id(user.id, fake_analytics)
      expect(fake_analytics).
        to_not have_logged_event(Analytics::DOCUMENT_CAPTURE_SESSION_OVERWRITTEN, {})
    end
  end
end
