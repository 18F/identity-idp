require 'rails_helper'

describe DocumentCaptureSessionResult do
  let(:id) { SecureRandom.uuid }
  let(:success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }

  describe '.key' do
    it 'generates a key' do
      key = DocumentCaptureSessionResult.key(id)
      expect(key).to eq('dcs:result:' + id)
    end
  end

  describe '.store' do
    it 'writes encrypted data to redis' do
      DocumentCaptureSessionResult.store(id: id, success: success, pii: pii)

      data = REDIS_POOL.with { |client| client.read(DocumentCaptureSessionResult.key(id)) }

      expect(data).to be_a(String)
      expect(data).to_not include('Testy')
      expect(data).to_not include('Testerson')
    end
  end

  describe '.load' do
    it 'reads the unloaded result from the session' do
      DocumentCaptureSessionResult.store(id: id, success: success, pii: pii)

      loaded_result = DocumentCaptureSessionResult.load(id)

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.success?).to eq(success)
      expect(loaded_result.pii).to eq(pii)
    end

    it 'returns nil if no data exists in redis' do
      loaded_result = DocumentCaptureSessionResult.load(SecureRandom.uuid)

      expect(loaded_result).to eq(nil)
    end
  end
end
