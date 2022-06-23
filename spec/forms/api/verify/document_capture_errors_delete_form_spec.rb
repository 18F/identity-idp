require 'rails_helper'

describe Api::Verify::DocumentCaptureErrorsDeleteForm do
  let(:document_capture_session_uuid) { nil }
  subject(:form) do
    described_class.new(document_capture_session_uuid: document_capture_session_uuid)
  end

  describe '#submit' do
    context 'without a document capture session uuid' do
      it 'is returns an unsuccessful form response' do
        result, document_capture_session = form.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(
          { document_capture_session_uuid: ['Please fill in this field.'] },
        )
        expect(document_capture_session).to be_nil
      end
    end

    context 'with an invalid document capture session uuid' do
      let(:document_capture_session_uuid) { 'wrong' }

      it 'is returns an unsuccessful form response' do
        result, document_capture_session = form.submit

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(
          { document_capture_session_uuid: ['Invalid document capture session'] },
        )
        expect(document_capture_session).to be_nil
      end
    end

    context 'with a valid document capture session uuid' do
      let(:document_capture_session) { DocumentCaptureSession.create }
      let(:document_capture_session_uuid) { document_capture_session.uuid }

      it 'is returns an successful form response' do
        result, resolved_document_capture_session = form.submit

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
        expect(resolved_document_capture_session).to eq(document_capture_session)
      end
    end
  end
end
