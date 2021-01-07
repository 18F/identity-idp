require 'rails_helper'

RSpec.describe Idv::ApiImageUploadForm do
  subject(:form) do
    Idv::ApiImageUploadForm.new(
      {
        front: front_image,
        back: back_image,
        selfie: selfie_image,
        document_capture_session_uuid: document_capture_session_uuid,
      },
      liveness_checking_enabled: liveness_checking_enabled?,
    )
  end

  let(:front_image) { DocAuthImageFixtures.document_front_image_multipart }
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
  let!(:document_capture_session) { DocumentCaptureSession.create! }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:liveness_checking_enabled?) { true }

  describe '#valid?' do
    context 'with all valid images' do
      it 'is valid' do
        expect(form.valid?).to eq(true)
        expect(form.errors).to be_blank
      end
    end

    context 'with valid front and back but no selfie' do
      let(:selfie_image) { nil }

      context 'with liveness required' do
        let(:liveness_checking_enabled?) { true }

        it 'is not valid' do
          expect(form.valid?).to eq(false)
          expect(form.errors[:selfie]).to eq(['Please fill in this field.'])
        end
      end

      context 'without liveness require' do
        let(:liveness_checking_enabled?) { false }

        it 'is valid' do
          expect(form.valid?).to eq(true)
          expect(form.errors).to be_blank
        end
      end
    end

    context 'when document_capture_session_uuid param is missing' do
      let(:document_capture_session_uuid) { nil }

      it 'is not valid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:document_capture_session]).to eq(['Please fill in this field.'])
      end
    end

    context 'when document_capture_session_uuid does not correspond to a record' do
      let(:document_capture_session_uuid) { 'unassociated-test-uuid' }

      it 'is not valid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:document_capture_session]).to eq(['Please fill in this field.'])
      end
    end

    context 'when throttled from submission' do
      before do
        allow(Throttler::IsThrottledElseIncrement).to receive(:call).once.and_return(true)
        form.submit
      end

      it 'is not valid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:limit]).to eq([I18n.t('errors.doc_auth.acuant_throttle')])
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
