require 'rails_helper'

RSpec.describe ProofingSessionAsyncResult do
  let(:id) { SecureRandom.uuid }
  let(:status) { ProofingSessionAsyncResult::DONE }
  let(:idv_result) { { errors: {}, messages: ['some message'] } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = ProofingSessionAsyncResult.new(id: id, status: status, result: idv_result)

      EncryptedRedisStructStorage.store(result)

      loaded_result = EncryptedRedisStructStorage.load(
        id, type: ProofingSessionAsyncResult
      )

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.status).to eq(status)

      expect(loaded_result.result).to eq(idv_result.deep_symbolize_keys)
    end
  end

  context 'proofing timed out' do
    let(:idv_result) { { errors: {}, messages: ['some message'], timed_out: true } }

    it 'indicates a timeout' do
      result = ProofingSessionAsyncResult.new(id: id, status: status, result: idv_result)

      expect(result.timed_out?).to be
    end
  end
end
