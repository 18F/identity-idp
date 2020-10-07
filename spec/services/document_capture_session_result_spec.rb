require 'rails_helper'

describe DocumentCaptureSessionResult do
  let(:id) { SecureRandom.uuid }
  let(:success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = DocumentCaptureSessionResult.new(id: id, success: success, pii: pii)
      EncryptedRedisStructStorage.store(result)
      loaded_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.success?).to eq(success)
      expect(loaded_result.pii).to eq(pii.deep_symbolize_keys)
    end
  end
end
