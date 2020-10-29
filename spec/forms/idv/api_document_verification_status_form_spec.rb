require 'rails_helper'

RSpec.describe Idv::ApiDocumentVerificationStatusForm do
  subject(:form) do
    Idv::ApiDocumentVerificationStatusForm.new(
      async_state: async_state,
      document_capture_session: document_capture_session,
    )
  end

  let(:async_state) { ProofingDocumentCaptureSessionResult.none }
  let(:document_capture_session) { DocumentCaptureSession.create! }

  describe '#valid?' do
    context 'with timeout async state' do
      let(:async_state) { ProofingDocumentCaptureSessionResult.timed_out }

      it 'is invalid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:timeout]).to eq([t('errors.doc_auth.document_verification_timeout')])
      end
    end

    context 'with pending result' do
      let(:async_state) { ProofingDocumentCaptureSessionResult.in_progress }

      it 'is valid' do
        expect(form.valid?).to eq(true)
      end
    end

    context 'with unsuccessful result' do
      let(:async_state) do
        ProofingDocumentCaptureSessionResult.new(
          id: nil,
          pii: nil,
          result: {
            success: false,
            errors: { front: 'Wrong document' },
          },
          status: :done
        )
      end

      it 'is invalid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:front]).to eq(['Wrong document'])
      end
    end

    context 'with successful result' do
      let(:async_state) do
        ProofingDocumentCaptureSessionResult.new(
          id: nil,
          pii: nil,
          result: {
            success: true,
          },
          status: :done
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
  end
end
