require 'rails_helper'

RSpec.describe DocumentCaptureSessionAsyncResult do
  let(:id) { SecureRandom.uuid }
  let(:status) { DocumentCaptureSessionAsyncResult::IN_PROGRESS }
  let(:idv_result) { nil }

  subject do
    result = DocumentCaptureSessionAsyncResult.new(id: id, status: status, result: idv_result)
    EncryptedRedisStructStorage.store(result)
    EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionAsyncResult)
  end

  describe 'success?' do
    context 'with incomplete result' do
      it 'is false' do
        expect(subject.success?).to eq false
      end
    end

    context 'with complete result' do
      let(:status) { DocumentCaptureSessionAsyncResult::DONE }

      context 'with unsuccessful result' do
        let(:idv_result) { { success: false, errors: {}, messages: ['some message'] } }

        it 'is false' do
          expect(subject.success?).to eq false
        end
      end

      context 'with successful result' do
        let(:idv_result) { { success: true, errors: {}, messages: [] } }

        it 'is true' do
          expect(subject.success?).to eq true
        end
      end
    end
  end

  describe 'attention_with_barcode?' do
    it { expect(subject.attention_with_barcode?).to eq false }

    context 'with complete result' do
      let(:status) { DocumentCaptureSessionAsyncResult::DONE }
      let(:idv_result) { { success: true, attention_with_barcode: false } }

      it { expect(subject.attention_with_barcode?).to eq false }

      context 'with attention with barcode result' do
        let(:idv_result) { { success: true, attention_with_barcode: true } }

        it { expect(subject.attention_with_barcode?).to eq true }
      end
    end
  end
end
