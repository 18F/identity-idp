require 'rails_helper'

RSpec.describe Idv::ApiImageUploadForm do
  include AnalyticsEvents

  subject(:form) do
    Idv::ApiImageUploadForm.new(
      ActionController::Parameters.new(
        front: front_image,
        front_image_metadata: front_image_metadata,
        back: back_image,
        back_image_metadata: back_image_metadata,
        document_capture_session_uuid: document_capture_session_uuid,
      ),
      service_provider: build(:service_provider, issuer: 'test_issuer'),
      analytics: fake_analytics,
      irs_attempts_api_tracker: irs_attempts_api_tracker,
      store_encrypted_images: store_encrypted_images,
    )
  end

  let(:front_image) { DocAuthImageFixtures.document_front_image_multipart }
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:front_image_metadata) do
    { width: 40, height: 40, mimeType: 'image/png', source: 'upload' }.to_json
  end
  let(:back_image_metadata) do
    { width: 20, height: 20, mimeType: 'image/png', source: 'upload' }.to_json
  end
  let!(:document_capture_session) { DocumentCaptureSession.create!(user: create(:user)) }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:irs_attempts_api_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:store_encrypted_images) { false }

  describe '#valid?' do
    context 'with all valid images' do
      it 'is valid' do
        expect(form.valid?).to eq(true)
        expect(form.errors).to be_blank
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
        Throttle.new(
          throttle_type: :idv_doc_auth,
          user: document_capture_session.user,
        ).increment_to_throttled!
        form.submit
      end

      it 'is not valid' do
        expect(irs_attempts_api_tracker).to receive(:idv_document_upload_rate_limited).with(no_args)
        expect(form.valid?).to eq(false)
        expect(form.errors[:limit]).to eq([I18n.t('errors.doc_auth.throttled_heading')])
      end
    end
  end

  describe '#submit' do
    context 'with a valid form' do
      it 'logs analytics' do
        form.submit

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          attempts: 1,
          remaining_attempts: 3,
          user_id: document_capture_session.user.uuid,
        )
      end

      it 'returns the expected response' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq(Idp::Constants::MOCK_IDV_APPLICANT)
      end
    end

    context 'image data returns unknown errors' do
      let(:back_image) do
        Rack::Test::UploadedFile.new(StringIO.new(<<~YAML), original_filename: 'ial2.yml')
          failed_alerts:
          - name: Some Made Up Error
        YAML
      end

      it 'logs a doc auth warning' do
        form.submit

        expect(fake_analytics).to have_logged_event('Doc Auth Warning', {})
      end

      it 'returns the expected response' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(false)
        expect(response.errors).to eq(
          {
            general: [t('doc_auth.errors.general.no_liveness')],
            hints: true,
            front: [t('doc_auth.errors.general.fallback_field_level')],
            back: [t('doc_auth.errors.general.fallback_field_level')],
          },
        )
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq({})
      end
    end

    context 'invalid metadata shape' do
      let(:back_image_metadata) { '{' }

      it 'logs analytics excluding invalid metadata' do
        form.submit

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          attempts: 1,
          remaining_attempts: 3,
          user_id: document_capture_session.user.uuid,
        )
      end

      it 'returns the expected response' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq(Idp::Constants::MOCK_IDV_APPLICANT)
      end
    end

    context 'form is missing a required param' do
      let(:front_image) { nil }

      it 'is not successful' do
        response = form.submit

        expect(response).to be_a_kind_of Idv::DocAuthFormResponse
        expect(response.success?).to eq(false)
        expect(response.errors).to eq({ front: [t('errors.messages.blank')] })
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq({})
      end

      it 'includes remaining_attempts' do
        response = form.submit
        expect(response.extra[:remaining_attempts]).to be_a_kind_of(Numeric)
      end
    end

    context 'posting images to client fails' do
      let(:failed_response) do
        DocAuth::Response.new(
          success: false,
          errors: { front: 'glare' },
          extra: { remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1 },
        )
      end
      before do
        allow(subject).to receive(:post_images_to_client).and_return(failed_response)
      end

      it 'is not successful' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(false)
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq({})
      end

      it 'includes remaining_attempts' do
        response = form.submit
        expect(response.extra[:remaining_attempts]).to be_a_kind_of(Numeric)
      end

      it 'includes client response errors' do
        response = form.submit
        expect(response.errors[:front]).to eq('glare')
      end
    end

    context 'PII validation from client response fails' do
      let(:failed_response) do
        Idv::DocAuthFormResponse.new(
          success: false,
          errors: { doc_pii: 'bad' },
          extra: {
            pii_like_keypaths: [[:pii]],
            attention_with_barcode: false,
          },
        )
      end

      before do
        allow_any_instance_of(Idv::DocPiiForm).to receive(:submit).and_return(failed_response)
      end

      it 'is not successful' do
        response = form.submit

        expect(response.success?).to eq(false)
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq({})
      end

      it 'includes remaining_attempts' do
        response = form.submit
        expect(response.extra[:remaining_attempts]).to be_a_kind_of(Numeric)
      end

      it 'includes doc_pii errors' do
        response = form.submit
        expect(response.errors[:doc_pii]).to eq('bad')
      end
    end

    describe 'encrypted document storage' do
      context 'when encrypted image storage is enabled' do
        let(:store_encrypted_images) { true }

        it 'writes encrypted documents' do
          # This is not a _great_ way to test this. Once we start writing these events to the
          # attempts API we should use the fake attempts API to grab the 'reference` value for the
          # front and back image and check that those files are written.
          document_writer = form.send(:encrypted_document_storage_writer)

          expect(document_writer).to receive(:encrypt_and_write_document).with(
            front_image: DocAuthImageFixtures.document_front_image_multipart.read,
            back_image: DocAuthImageFixtures.document_back_image_multipart.read,
          ).and_call_original

          form.submit
        end
      end

      context 'when the attempts API is not enabled' do
        let(:store_encrypted_images) { false }

        it 'when encrypted image storage is disabled' do
          document_writer = instance_double(EncryptedDocumentStorage::DocumentWriter)
          allow(form).to receive(:encrypted_document_storage_writer).and_return(document_writer)

          expect(document_writer).to_not receive(:encrypt_and_write_document)

          form.submit
        end
      end
    end

    describe 'image source' do
      let(:source) { nil }
      let(:front_image_metadata) do
        { width: 40, height: 40, mimeType: 'image/png', source: source }.to_json
      end
      let(:back_image_metadata) do
        { width: 20, height: 20, mimeType: 'image/png', source: source }.to_json
      end
      let(:image_source) { nil }

      before do
        expect_any_instance_of(DocAuth::Mock::DocAuthMockClient).
          to receive(:post_images).
          with(hash_including(image_source: image_source)).
          and_call_original
      end

      context 'manual uploads' do
        let(:source) { 'upload' }
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          form.submit
        end
      end

      context 'mixed sources' do
        let(:source) { 'upload' }
        let(:back_image_metadata) do
          { width: 20, height: 20, mimeType: 'image/png', source: 'acuant' }.to_json
        end
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          form.submit
        end
      end

      context 'acuant images' do
        let(:source) { 'acuant' }
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }

        it 'sets image source to acuant sdk' do
          form.submit
        end
      end

      context 'malformed image metadata' do
        let(:source) { 'upload' }
        let(:front_image_metadata) { nil.to_json }
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          form.submit
        end
      end
    end
  end
end
