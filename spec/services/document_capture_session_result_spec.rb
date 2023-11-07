require 'rails_helper'

RSpec.describe DocumentCaptureSessionResult do
  let(:id) { SecureRandom.uuid }
  let(:success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = DocumentCaptureSessionResult.new(
        id:,
        success:,
        pii:,
        attention_with_barcode: false,
      )
      EncryptedRedisStructStorage.store(result)
      loaded_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.success?).to eq(success)
      expect(loaded_result.pii).to eq(pii.deep_symbolize_keys)
      expect(loaded_result.attention_with_barcode?).to eq(false)
    end
    it 'add fingerprint with EncryptedRedisStructStorage' do
      result = DocumentCaptureSessionResult.new(
        id:,
        success:,
        pii:,
        attention_with_barcode: false,
      )
      result.add_failed_front_image!('abcdefg')
      expect(result.failed_front_image_fingerprints.is_a?(Array)).to eq(true)
      expect(result.failed_front_image_fingerprints.length).to eq(1)
      expect(result.failed_front_image?('abcdefg')).to eq(true)
      expect(result.failed_front_image?(nil)).to eq(false)
      expect(result.failed_back_image?(nil)).to eq(false)
    end
  end
end
