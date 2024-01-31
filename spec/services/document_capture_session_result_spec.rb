require 'rails_helper'

RSpec.describe DocumentCaptureSessionResult do
  let(:id) { SecureRandom.uuid }
  let(:success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }

  context 'EncryptedRedisStructStorage' do
    it 'works with EncryptedRedisStructStorage' do
      result = DocumentCaptureSessionResult.new(
        id: id,
        doc_auth_success: success,
        selfie_status: :success,
        pii: pii,
        attention_with_barcode: false,
      )
      EncryptedRedisStructStorage.store(result)
      loaded_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)

      expect(loaded_result.id).to eq(id)
      expect(loaded_result.success?).to eq(success)
      expect(loaded_result)
      expect(loaded_result.pii).to eq(pii.deep_symbolize_keys)
      expect(loaded_result.attention_with_barcode?).to eq(false)
      expect(loaded_result.selfie_status).to eq(:success)
      expect(loaded_result.doc_auth_success).to eq(true)
      loaded_result.inspect
    end
    it 'add fingerprint with EncryptedRedisStructStorage' do
      result = DocumentCaptureSessionResult.new(
        id: id,
        pii: pii,
        attention_with_barcode: false,
      )
      result.add_failed_front_image!('abcdefg')
      expect(result.failed_front_image_fingerprints.is_a?(Array)).to eq(true)
      expect(result.failed_front_image_fingerprints.length).to eq(1)
      expect(result.failed_front_image?('abcdefg')).to eq(true)
      expect(result.failed_front_image?(nil)).to eq(false)
      expect(result.failed_back_image?(nil)).to eq(false)
    end
    describe '#selfie_status' do
      it 'returns a symbol' do
        result = DocumentCaptureSessionResult.new(
          id: id,
          success: success,
          pii: pii,
          attention_with_barcode: false,
          selfie_status: 'success',
        )
        expect(result.selfie_status).to be_an_instance_of(Symbol)
      end
    end

    describe '#success?' do
      it 'reports true when doc_auth_success is true and selfie_status is :not_processed' do
        result = DocumentCaptureSessionResult.new(
          id: id,
          success: false,
          pii: pii,
          attention_with_barcode: false,
          selfie_status: :not_processed,
          doc_auth_success: true,
        )
        expect(result.success?).to eq(true)
      end
      it 'reports failure when selfie_status is :fail' do
        result = DocumentCaptureSessionResult.new(
          id: id,
          success: false,
          pii: pii,
          attention_with_barcode: false,
          selfie_status: :fail,
          doc_auth_success: true,
        )
        expect(result.success?).to eq(false)
      end

      it 'reports failure when doc_auth_success is false' do
        result = DocumentCaptureSessionResult.new(
          id: id,
          success: false,
          pii: pii,
          attention_with_barcode: false,
          selfie_status: :success,
          doc_auth_success: false,
        )
        expect(result.success?).to eq(false)
      end

      describe 'hypothetically when old success field and contradicting new status filed' do
        it 'reports correct result' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: false,
            pii: pii,
            attention_with_barcode: false,
            selfie_status: :not_processed,
            doc_auth_success: true,
          )
          expect(result.success?).to eq(true)

          result = DocumentCaptureSessionResult.new(
            id: id,
            success: true,
            pii: pii,
            attention_with_barcode: false,
            selfie_status: :fail,
            doc_auth_success: true,
          )
          expect(result.success?).to eq(true)
        end
      end
    end
  end
end
