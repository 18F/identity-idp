require 'rails_helper'

RSpec.describe DocumentCaptureSessionResult do
  let(:id) { SecureRandom.uuid }
  let(:success) { true }
  let(:pii) { { 'first_name' => 'Testy', 'last_name' => 'Testerson' } }
  let(:selfie_required) { false }

  context 'EncryptedRedisStructStorage' do
    it 'add fingerprint with EncryptedRedisStructStorage' do
      result = DocumentCaptureSessionResult.new(
        id: id,
        success: success,
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
    context 'with selfie' do
      let(:selfie_required) { true }
      it 'works with EncryptedRedisStructStorage' do
        result = DocumentCaptureSessionResult.new(
          id: id,
          success: success,
          doc_auth_success: success,
          selfie_status: :success,
          pii: pii,
          attention_with_barcode: false,
        )
        EncryptedRedisStructStorage.store(result)
        loaded_result = EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionResult)

        expect(loaded_result.id).to eq(id)
        expect(loaded_result.success?(selfie_required: selfie_required)).to eq(success)
        expect(loaded_result.pii).to eq(pii.deep_symbolize_keys)
        expect(loaded_result.attention_with_barcode?).to eq(false)
        expect(loaded_result.selfie_status).to eq(:success)
        expect(loaded_result.doc_auth_success).to eq(true)
      end
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
        expect(result.success?(selfie_required: selfie_required)).to eq(true)
      end
      it 'reports correctly from false when missing doc_auth_success and selfie_status' do
        result = DocumentCaptureSessionResult.new(
          id: id,
          success: true,
          pii: pii,
          attention_with_barcode: false,
        )
        expect(result.success?(selfie_required: selfie_required)).to eq(false)
      end
      context 'when pii is not present' do
        it 'reports success status is failed' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: true,
            pii: nil,
            attention_with_barcode: false,
            doc_auth_success: true,
            selfie_status: :not_processed,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(false)
        end
      end
      context 'when selfie status is failed' do
        it 'reports success status is successful' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: false,
            pii: pii,
            attention_with_barcode: false,
            doc_auth_success: true,
            selfie_status: :fail,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(true)
        end
      end
      context 'when selfie status is success' do
        it 'reports success status is successful' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: false,
            pii: pii,
            attention_with_barcode: false,
            doc_auth_success: true,
            selfie_status: :success,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(true)
        end
      end

      context 'when a liveness check is required' do
        let(:selfie_required) { true }
        it 'reports failure when selfie_status is :fail' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: true,
            pii: pii,
            attention_with_barcode: false,
            selfie_status: :fail,
            doc_auth_success: true,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(false)
        end

        it 'reports failure when selfie_status is not_processed' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: true,
            pii: pii,
            attention_with_barcode: false,
            selfie_status: :not_processed,
            doc_auth_success: true,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(false)
        end

        it 'reports failure when doc_auth_success is false' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: true,
            pii: pii,
            attention_with_barcode: false,
            selfie_status: :success,
            doc_auth_success: false,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(false)
        end

        it 'reports failure when selfie_status is not_processed' do
          result = DocumentCaptureSessionResult.new(
            id: id,
            success: false,
            pii: pii,
            attention_with_barcode: false,
            selfie_status: :success,
            doc_auth_success: true,
          )
          expect(result.success?(selfie_required: selfie_required)).to eq(true)
        end
      end
    end
  end
end
