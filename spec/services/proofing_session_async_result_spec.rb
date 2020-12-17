require 'rails_helper'

RSpec.describe ProofingSessionAsyncResult do
  let(:id) { SecureRandom.uuid }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }
  let(:idv_result) { { errors: {}, messages: ['some message'] } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = ProofingSessionAsyncResult.new(id: id, pii: pii, result: idv_result)

      EncryptedRedisStructStorage.store(result)

      loaded_result = EncryptedRedisStructStorage.load(
        id, type: ProofingSessionAsyncResult
      )

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.pii).to eq(pii.deep_symbolize_keys)

      expect(loaded_result.result).to eq(idv_result.deep_symbolize_keys)
    end
  end
end
