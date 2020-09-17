require 'rails_helper'

RSpec.describe ProofingDocumentCaptureSessionResult do
  let(:id) { SecureRandom.uuid }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }
  let(:idv_result) { { errors: {}, messages: ['some message'] } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = ProofingDocumentCaptureSessionResult.new(id: id, pii: pii, result: idv_result)

      EncryptedRedisStructStorage.store(result)

      loaded_result = EncryptedRedisStructStorage.load(
        id, type: ProofingDocumentCaptureSessionResult
      )

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.pii).to eq(pii)

      expect(loaded_result.result).to eq(idv_result.with_indifferent_access)
    end
  end
end
