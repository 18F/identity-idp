require 'rails_helper'

RSpec.describe DocumentCaptureSessionAsyncResult do
  let(:id) { SecureRandom.uuid }
  let(:status) { DocumentCaptureSessionAsyncResult::NONE }
  let(:idv_result) { nil }

  describe 'success?' do
    subject do
      result = DocumentCaptureSessionAsyncResult.new(id: id, status: status, result: idv_result)
      EncryptedRedisStructStorage.store(result)
      EncryptedRedisStructStorage.load(id, type: DocumentCaptureSessionAsyncResult)
    end

    context 'with incomplete result' do
      let(:status) { DocumentCaptureSessionAsyncResult::IN_PROGRESS }

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
end
