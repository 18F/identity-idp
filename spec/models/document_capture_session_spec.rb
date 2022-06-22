require 'rails_helper'

describe DocumentCaptureSession do
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
      data = REDIS_POOL.with { |client| client.get(key) }
      expect(data).to be_a(String)
      expect(data).to_not include('Testy')
      expect(data).to_not include('Testerson')
      expect(record.ocr_confirmation_pending).to eq(false)
    end

    context 'with attention with barcode response' do
      before { allow(doc_auth_response).to receive(:attention_with_barcode?).and_return(true) }

      it 'sets record as pending ocr confirmation' do
        record = DocumentCaptureSession.new
        record.store_result_from_response(doc_auth_response)
        expect(record.ocr_confirmation_pending).to eq(true)
      end
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

  describe '#store_doc_auth_result' do
    it 'generates a result ID stores the result encrypted in redis' do
      record = DocumentCaptureSession.new(result_id: SecureRandom.uuid)

      record.store_doc_auth_result(
        result: doc_auth_response.to_h,
        pii: doc_auth_response.pii_from_doc,
      )

      result_id = record.result_id
      key = EncryptedRedisStructStorage.key(result_id, type: DocumentCaptureSessionAsyncResult)
      data = REDIS_POOL.with { |client| client.get(key) }
      expect(data).to be_a(String)
      expect(data).to_not include('Testy')
      expect(data).to_not include('Testerson')
      expect(record.ocr_confirmation_pending).to eq(false)
    end

    context 'with attention with barcode response' do
      before { allow(doc_auth_response).to receive(:attention_with_barcode?).and_return(true) }

      it 'sets record as pending ocr confirmation' do
        record = DocumentCaptureSession.new(result_id: SecureRandom.uuid)
        record.store_doc_auth_result(
          result: doc_auth_response.to_h,
          pii: doc_auth_response.pii_from_doc,
        )
        expect(record.ocr_confirmation_pending).to eq(true)
      end
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
end
