require 'rails_helper'

describe DocumentCaptureSessionResult do
  describe '.key' do
    it 'generates a key' do
      id = 'test-id'
      key = DocumentCaptureSessionResult.key(id)
      expect(key).to eq('dcs:result:test-id')
    end
  end

  describe '#unload' do
    it 'writes encrypted data to redis' do
      result = DocumentCaptureSessionResult.new(
        id: SecureRandom.uuid,
        success: true,
        pii: { 'first_name' => 'Testy', 'last_name' => 'Testerson' },
      )

      result.unload

      data = REDIS_POOL.with { |client| client.read(DocumentCaptureSessionResult.key(result.id)) }
      expect(data).to be_a(String)
      expect(data).to_not include('Testy')
      expect(data).to_not include('Testerson')
    end
  end

  describe '.load' do
    it 'reads the unloaded result from the session' do
      unloaded_result = DocumentCaptureSessionResult.new(
        id: SecureRandom.uuid,
        success: true,
        pii: { 'first_name' => 'Testy', 'last_name' => 'Testerson' },
      )
      unloaded_result.unload

      loaded_result = DocumentCaptureSessionResult.load(unloaded_result.id)

      expect(loaded_result.id).to eq(unloaded_result.id)
      expect(loaded_result.success?).to eq(unloaded_result.success?)
      expect(loaded_result.pii).to eq(unloaded_result.pii)
    end

    it 'returns nil if no data exists in redis' do
      loaded_result = DocumentCaptureSessionResult.load(SecureRandom.uuid)

      expect(loaded_result).to eq(nil)
    end
  end
end
