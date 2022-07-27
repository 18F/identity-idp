require 'rails_helper'

RSpec.describe Idv::ApiDocumentVerificationStatusForm do
  subject(:form) do
    Idv::ApiDocumentVerificationStatusForm.new(
      async_state: async_state,
      document_capture_session: document_capture_session,
    )
  end

  let(:async_state) { DocumentCaptureSessionAsyncResult.new }
  let(:document_capture_session) { DocumentCaptureSession.create!(user: build(:user)) }

  describe '#valid?' do
    context 'with missing async state' do
      let(:async_state) do
        DocumentCaptureSessionAsyncResult.new(status: DocumentCaptureSessionAsyncResult::MISSING)
      end

      it 'is invalid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:timeout]).to eq([t('errors.doc_auth.document_verification_timeout')])
      end
    end

    context 'with missing document capture session' do
      let(:document_capture_session) { nil }

      it 'is invalid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:document_capture_session]).to eq([t('errors.messages.blank')])
      end
    end

    context 'with pending result' do
      let(:async_state) do
        DocumentCaptureSessionAsyncResult.new(
          status: DocumentCaptureSessionAsyncResult::IN_PROGRESS,
        )
      end

      it 'is valid' do
        expect(form.valid?).to eq(true)
      end
    end

    context 'with unsuccessful result' do
      let(:async_state) do
        DocumentCaptureSessionAsyncResult.new(
          id: nil,
          pii: nil,
          result: {
            success: false,
            errors: { front: 'Wrong document' },
          },
          status: DocumentCaptureSessionAsyncResult::DONE,
        )
      end

      it 'is invalid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:front]).to eq(['Wrong document'])
      end
    end

    context 'with successful result' do
      let(:async_state) do
        DocumentCaptureSessionAsyncResult.new(
          id: nil,
          pii: nil,
          result: {
            success: true,
          },
          status: DocumentCaptureSessionAsyncResult::DONE,
        )
      end

      it 'is valid' do
        expect(form.valid?).to eq(true)
      end
    end
  end

  describe '#submit' do
    it 'includes remaining_attempts' do
      response = form.submit
      expect(response.extra[:remaining_attempts]).to be_a_kind_of(Numeric)
    end

    it 'includes doc_auth_result' do
      response = form.submit
      expect(response.extra[:doc_auth_result]).to be_nil

      expect(async_state).to receive(:result).and_return(doc_auth_result: nil)
      response = form.submit
      expect(response.extra[:doc_auth_result]).to be_nil

      expect(async_state).to receive(:result).and_return(doc_auth_result: 'Failed')
      response = form.submit
      expect(response.extra[:doc_auth_result]).to eq('Failed')
    end
  end
end
