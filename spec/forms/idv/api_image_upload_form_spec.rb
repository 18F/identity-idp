require 'rails_helper'

RSpec.describe Idv::ApiImageUploadForm do
  include DocPiiHelper

  subject(:form) do
    Idv::ApiImageUploadForm.new(
      ActionController::Parameters.new(
        front: front_image,
        front_image_metadata: front_image_metadata,
        back: back_image,
        back_image_metadata: back_image_metadata,
        selfie: selfie_image,
        document_capture_session_uuid: document_capture_session_uuid,
      ),
      service_provider: build(:service_provider, issuer: 'test_issuer'),
      analytics: fake_analytics,
      irs_attempts_api_tracker: irs_attempts_api_tracker,
      store_encrypted_images: store_encrypted_images,
      liveness_checking_enabled: liveness_checking_enabled,
    )
  end

  let(:front_image) { DocAuthImageFixtures.document_front_image_multipart }
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:selfie_image) { nil }
  let(:liveness_checking_enabled) { false }
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

    context 'when rate limited from submission' do
      it 'is not valid' do
        expect(irs_attempts_api_tracker).to receive(:idv_document_upload_rate_limited).with(no_args)

        RateLimiter.new(
          rate_limit_type: :idv_doc_auth,
          user: document_capture_session.user,
        ).increment_to_limited!
        form.submit

        expect(form.valid?).to eq(false)
        expect(form.errors[:limit]).to eq([I18n.t('errors.doc_auth.rate_limited_heading')])
      end
    end

    context 'when liveness check is enabled' do
      let(:liveness_checking_enabled) { true }
      it 'is not valid without selfie' do
        expect(form.valid?).to eq(false)
      end
      context 'with valid selfie' do
        let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
        it 'is valid' do
          expect(form.valid?).to eq(true)
        end
      end
    end
  end

  describe '#submit' do
    context 'with a valid form' do
      it 'logs analytics' do
        expect(irs_attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
          {
            address: '1 FAKE RD',
            date_of_birth: '1938-10-06',
            document_back_image_filename: nil,
            document_expiration: '2099-12-31',
            document_front_image_filename: nil,
            document_image_encryption_key: nil,
            document_issued: '2019-12-31',
            document_number: '1111111111111',
            document_state: 'MT',
            first_name: 'FAKEY',
            last_name: 'MCFAKERSON',
            success: true,
          },
        )

        form.submit

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          attempts: 1,
          remaining_attempts: 3,
          user_id: document_capture_session.user.uuid,
          flow_path: anything,
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          getting_started_ab_test_bucket: :welcome_default,
          phone_question_ab_test_bucket: :bypass_phone_question,
          phone_with_camera: nil,
        )

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          async: false,
          attempts: 1,
          attention_with_barcode: false,
          billed: true,
          client_image_metrics: {
            back: {
              height: 20,
              mimeType: 'image/png',
              source: 'upload',
              width: 20,
            },
            front: {
              height: 40,
              mimeType: 'image/png',
              source: 'upload',
              width: 40,
            },
          },
          doc_auth_result: 'Passed',
          errors: {},
          exception: nil,
          flow_path: anything,
          remaining_attempts: 3,
          state: 'MT',
          state_id_type: 'drivers_license',
          success: true,
          user_id: document_capture_session.user.uuid,
          vendor_request_time_in_ms: a_kind_of(Float),
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          doc_type_supported: boolean,
          getting_started_ab_test_bucket: :welcome_default,
          phone_question_ab_test_bucket: :bypass_phone_question,
          phone_with_camera: nil,
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

        expect(fake_analytics).to have_logged_event('Doc Auth Warning')
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
          flow_path: anything,
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          getting_started_ab_test_bucket: :welcome_default,
          phone_question_ab_test_bucket: :bypass_phone_question,
          phone_with_camera: nil,
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

      it 'keeps fingerprints of failed image and triggers error when submit same image' do
        form.submit
        session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
        capture_result = session.load_result
        expect(capture_result.failed_front_image_fingerprints).not_to match_array([])
        response = form.submit
        expect(response.errors).to have_key(:front)
        expect(response.errors).to have_value([I18n.t('doc_auth.errors.doc.resubmit_failed_image')])
      end
    end

    context 'PII validation from client response fails' do
      let(:failed_response) do
        Idv::DocAuthFormResponse.new(
          success: false,
          errors: { doc_pii: 'bad' },
          extra: {
            pii_like_keypaths: pii_like_keypaths,
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
        expect(irs_attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
          hash_including(
            {
              success: false,
            },
          ),
        )
        response = form.submit
        expect(response.errors[:doc_pii]).to eq('bad')
      end

      it 'keeps fingerprints of failed image and triggers error when submit same image' do
        form.submit
        session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
        capture_result = session.load_result
        expect(capture_result.failed_front_image_fingerprints).not_to match_array([])
        response = form.submit
        expect(response.errors).to have_key(:front)
        expect(response.errors).to have_value([I18n.t('doc_auth.errors.doc.resubmit_failed_image')])
        expect(fake_analytics).to have_logged_event(
          'IdV: failed doc image resubmitted',
          attempts: 1,
          remaining_attempts: 3,
          user_id: document_capture_session.user.uuid,
          flow_path: anything,
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          getting_started_ab_test_bucket: :welcome_default,
          phone_question_ab_test_bucket: :bypass_phone_question,
          phone_with_camera: nil,
          side: 'both',
        )
      end
    end

    describe 'encrypted document storage' do
      context 'when encrypted image storage is enabled' do
        let(:store_encrypted_images) { true }

        it 'writes encrypted documents' do
          form.submit

          upload_events = irs_attempts_api_tracker.events[:idv_document_upload_submitted]
          expect(upload_events).to have_attributes(length: 1)
          upload_event = upload_events.first

          document_writer = form.send(:encrypted_document_storage_writer)

          front_image.rewind
          back_image.rewind

          cipher = Encryption::AesCipher.new

          front_image_ciphertext =
            document_writer.storage.read_image(name: upload_event[:document_front_image_filename])

          back_image_ciphertext =
            document_writer.storage.read_image(name: upload_event[:document_back_image_filename])

          key = Base64.decode64(upload_event[:document_image_encryption_key])

          expect(cipher.decrypt(front_image_ciphertext, key)).to eq(front_image.read)
          expect(cipher.decrypt(back_image_ciphertext, key)).to eq(back_image.read)
        end
      end

      context 'when encrypted image storage is disabled' do
        let(:store_encrypted_images) { false }

        it 'does not write images' do
          document_writer = instance_double(EncryptedDocumentStorage::DocumentWriter)
          allow(form).to receive(:encrypted_document_storage_writer).and_return(document_writer)

          expect(document_writer).to_not receive(:encrypt_and_write_document)

          form.submit
        end

        it 'does not send image info to attempts api' do
          expect(irs_attempts_api_tracker).to receive(:idv_document_upload_submitted).with(
            hash_including(
              document_front_image_filename: nil,
              document_back_image_filename: nil,
              document_image_encryption_key: nil,
            ),
          )

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
  describe '#store_failed_images' do
    let(:doc_pii_response) { instance_double(Idv::DocAuthFormResponse) }
    let(:client_response) { instance_double(DocAuth::Response) }
    context 'when client_response is not success and not network error' do
      context 'when both sides error message missing' do
        let(:errors) { {} }
        it 'stores both sides as failed' do
          allow(client_response).to receive(:success?).and_return(false)
          allow(client_response).to receive(:network_error?).and_return(false)
          allow(client_response).to receive(:errors).and_return(errors)
          form.send(:validate_form)
          capture_result = form.send(:store_failed_images, client_response, doc_pii_response)
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end
      context 'when both sides error message exist' do
        let(:errors) { { front: 'blurry', back: 'dpi' } }
        it 'stores both sides as failed' do
          allow(client_response).to receive(:success?).and_return(false)
          allow(client_response).to receive(:network_error?).and_return(false)
          allow(client_response).to receive(:errors).and_return(errors)
          form.send(:validate_form)
          capture_result = form.send(:store_failed_images, client_response, doc_pii_response)
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end
      context 'when one sides error message exists' do
        let(:errors) { { front: 'blurry', back: nil } }
        it 'stores only the error side as failed' do
          allow(client_response).to receive(:success?).and_return(false)
          allow(client_response).to receive(:network_error?).and_return(false)
          allow(client_response).to receive(:errors).and_return(errors)
          form.send(:validate_form)
          capture_result = form.send(:store_failed_images, client_response, doc_pii_response)
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).to be_empty
        end
      end
    end

    context 'when client_response is not success and is network error' do
      let(:errors) { {} }
      context 'when doc_pii_response is success' do
        it 'stores neither of the side as failed' do
          allow(client_response).to receive(:success?).and_return(false)
          allow(client_response).to receive(:network_error?).and_return(true)
          allow(client_response).to receive(:errors).and_return(errors)
          allow(doc_pii_response).to receive(:success?).and_return(true)
          form.send(:validate_form)
          capture_result = form.send(:store_failed_images, client_response, doc_pii_response)
          expect(capture_result[:front]).to be_empty
          expect(capture_result[:back]).to be_empty
        end
      end
      context 'when doc_pii_response is failure' do
        it 'stores both sides as failed' do
          allow(client_response).to receive(:success?).and_return(false)
          allow(client_response).to receive(:network_error?).and_return(true)
          allow(client_response).to receive(:errors).and_return(errors)
          allow(doc_pii_response).to receive(:success?).and_return(false)
          form.send(:validate_form)
          capture_result = form.send(:store_failed_images, client_response, doc_pii_response)
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end
    end
  end
end
