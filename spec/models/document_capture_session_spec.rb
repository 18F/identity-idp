require 'rails_helper'

describe DocumentCaptureSession do
  let(:doc_auth_response) do
    DocAuthClient::Response.new(
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
      data = REDIS_POOL.with { |client| client.read(DocumentCaptureSessionResult.key(result_id)) }
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
      expect(result.pii).to eq(doc_auth_response.pii_from_doc.stringify_keys)
    end

    it 'returns nil if the previously stored result does not exist or expired' do
      record = DocumentCaptureSession.new
      result = record.load_result

      expect(result).to eq(nil)
    end
  end
end
