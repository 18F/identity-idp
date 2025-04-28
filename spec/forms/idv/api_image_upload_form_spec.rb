require 'rails_helper'

RSpec.describe Idv::ApiImageUploadForm do
  include DocPiiHelper

  subject(:form) do
    Idv::ApiImageUploadForm.new(
      ActionController::Parameters.new(
        {
          front: front_image,
          front_image_metadata: front_image_metadata.to_json,
          back: back_image,
          back_image_metadata: back_image_metadata.to_json,
          selfie: selfie_image,
          selfie_image_metadata: selfie_image_metadata.to_json,
          document_capture_session_uuid: document_capture_session_uuid,
        }.compact,
      ),
      service_provider: build(:service_provider, issuer: 'test_issuer'),
      attempts_api_tracker:,
      analytics: fake_analytics,
      attempts_api_tracker:,
      liveness_checking_required:,
      acuant_sdk_upgrade_ab_test_bucket:,
    )
  end

  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:front_image) { DocAuthImageFixtures.document_front_image_multipart }
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:selfie_image) { nil }
  let(:liveness_checking_required) { false }
  let(:front_image_file_name) { 'front.jpg' }
  let(:back_image_file_name) { 'back.jpg' }
  let(:selfie_image_file_name) { 'selfie.jpg' }
  let(:store_encrypted_images) { false }
  let(:document_type) { 'DriversLicense' }
  let(:front_image_metadata) do
    {
      width: 40,
      height: 40,
      mimeType: 'image/png',
      source: 'upload',
      fileName: front_image_file_name,
    }
  end

  let(:back_image_metadata) do
    {
      width: 20,
      height: 20,
      mimeType: 'image/png',
      source: 'upload',
      fileName: back_image_file_name,
    }
  end
  let(:selfie_image_metadata) { nil }
  let!(:document_capture_session) { create(:document_capture_session, doc_auth_vendor: 'mock') }
  let(:document_capture_session_uuid) { document_capture_session.uuid }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:acuant_sdk_upgrade_ab_test_bucket) {}
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }

  let(:writer) { EncryptedDocStorage::DocWriter.new }
  let(:doc_escrow_enabled) { false }
  let(:result) do
    EncryptedDocStorage::DocWriter::Result.new(name: 'name', encryption_key: '12345')
  end

  before do
    allow(attempts_api_tracker).to receive(:enabled?).and_return doc_escrow_enabled
    allow(writer).to receive(:write).and_return result
  end

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
        expect(attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :idv_doc_auth,
        )
        RateLimiter.new(
          rate_limit_type: :idv_doc_auth,
          user: document_capture_session.user,
        ).increment_to_limited!
        form.submit

        expect(form.valid?).to eq(false)
        expect(form.errors[:limit]).to eq([I18n.t('doc_auth.errors.rate_limited_heading')])
      end
    end

    context 'when liveness check is required' do
      let(:liveness_checking_required) { true }
      it 'is not valid without selfie' do
        expect(form.valid?).to eq(false)
      end
      context 'with valid selfie' do
        let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
        it 'is valid' do
          expect(form.valid?).to eq(true)
        end

        context 'validates image source' do
          let(:selfie_image_metadata) do
            { width: 40, height: 40, mimeType: 'image/png', source: 'acuant' }
          end
          before do
            allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode)
              .and_return(false)
          end

          context 'id images are uploaded' do
            it 'is invalid' do
              expect(form.valid?).to eq(false)
            end
          end

          context 'images sourced by acuant sdk' do
            let(:front_image_metadata) do
              {
                width: 40,
                height: 40,
                mimeType: 'image/png',
                source: 'acuant',
                fileName: front_image_file_name,
              }
            end
            let(:back_image_metadata) do
              {
                width: 20,
                height: 20,
                mimeType: 'image/png',
                source: 'acuant',
                fileName: back_image_file_name,
              }
            end
            it 'is valid' do
              expect(form.valid?).to eq(true)
            end

            context 'selfie is uploaded' do
              let(:selfie_image_metadata) do
                {
                  width: 40,
                  height: 40,
                  mimeType: 'image/png',
                  source: 'upload',
                  fileName: selfie_image_file_name,
                }
              end
              it 'is invalid' do
                expect(form.valid?).to eq(false)
              end
            end
          end
        end
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
          submit_attempts: 1,
          remaining_submit_attempts: 3,
          user_id: document_capture_session.user.uuid,
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          liveness_checking_required: boolean,
          document_type: document_type,
        )

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          async: false,
          submit_attempts: 1,
          attention_with_barcode: false,
          billed: true,
          client_image_metrics: {
            back: {
              height: 20,
              mimeType: 'image/png',
              source: 'upload',
              width: 20,
              fileName: back_image_file_name,
            },
            front: {
              height: 40,
              mimeType: 'image/png',
              source: 'upload',
              width: 40,
              fileName: front_image_file_name,
            },
          },
          doc_auth_result: 'Passed',
          errors: {},
          remaining_submit_attempts: 3,
          state: 'MT',
          country: 'US',
          state_id_type: 'drivers_license',
          success: true,
          user_id: document_capture_session.user.uuid,
          vendor_request_time_in_ms: a_kind_of(Float),
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          doc_type_supported: boolean,
          liveness_checking_required: boolean,
          selfie_live: boolean,
          selfie_quality_good: boolean,
          doc_auth_success: boolean,
          selfie_status: anything,
          workflow: 'test_non_liveness_workflow',
          birth_year: 1938,
          zip_code: '59010',
          issue_year: 2019,
          document_type: document_type,
        )
      end

      context 'the attempts_api_tracker is enabled' do
        let(:doc_escrow_enabled) { true }

        before do
          expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
          allow(writer).to receive(:write).exactly(3).times

          # testing that the storage is happening
          expect(writer).to receive(:write).with(image: form.send(:back_image_bytes))
            .and_return result
          expect(writer).to receive(:write).with(image: form.send(:front_image_bytes))
            .and_return result
          expect(writer).to receive(:write).with(image: nil).and_call_original
        end

        it 'tracks the event' do
          expect(attempts_api_tracker).to receive(:idv_document_uploaded).with(
            success: true,
            document_back_image_encryption_key: '12345',
            document_back_image_file_id: 'name',
            document_front_image_encryption_key: '12345',
            document_front_image_file_id: 'name',
            selfie_image_encryption_key: nil,
            selfie_image_file_id: nil,
            failure_reason: nil,
          )
          form.submit
        end
      end

      it 'returns the expected response' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(true)
        expect(response.doc_auth_success?).to eq(true)
        expect(response.selfie_status).to eq(:not_processed)
        expect(response.errors).to eq({})
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq(Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT))
      end

      context 'when liveness check is required' do
        let(:liveness_checking_required) { true }
        let(:back_image) { DocAuthImageFixtures.portrait_match_success_yaml }
        let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
        let(:selfie_image_metadata) do
          { width: 10, height: 10, mimeType: 'image/png', source: 'upload' }
        end

        it 'logs analytics' do
          form.submit

          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth image upload form submitted',
            success: true,
            submit_attempts: 1,
            remaining_submit_attempts: 3,
            user_id: document_capture_session.user.uuid,
            front_image_fingerprint: an_instance_of(String),
            back_image_fingerprint: an_instance_of(String),
            selfie_image_fingerprint: an_instance_of(String),
            liveness_checking_required: boolean,
            document_type: document_type,
          )

          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth image upload vendor submitted',
            async: false,
            submit_attempts: 1,
            attention_with_barcode: false,
            billed: true,
            client_image_metrics: {
              back: {
                height: 20,
                mimeType: 'image/png',
                source: 'upload',
                width: 20,
                fileName: back_image_file_name,
              },
              front: {
                height: 40,
                mimeType: 'image/png',
                source: 'upload',
                width: 40,
                fileName: front_image_file_name,
              },
              selfie: {
                height: 10,
                mimeType: 'image/png',
                source: 'upload',
                width: 10,
              },
            },
            doc_auth_result: 'Passed',
            errors: {},
            liveness_checking_required: boolean,
            portrait_match_results: anything,
            remaining_submit_attempts: 3,
            state: 'MT',
            country: 'US',
            state_id_type: 'drivers_license',
            success: true,
            user_id: document_capture_session.user.uuid,
            vendor_request_time_in_ms: a_kind_of(Float),
            front_image_fingerprint: an_instance_of(String),
            back_image_fingerprint: an_instance_of(String),
            selfie_image_fingerprint: an_instance_of(String),
            doc_type_supported: boolean,
            selfie_live: boolean,
            selfie_quality_good: boolean,
            doc_auth_success: boolean,
            selfie_status: :success,
            workflow: 'test_liveness_workflow',
            birth_year: 1938,
            zip_code: '59010',
            issue_year: 2019,
            selfie_attempts: a_kind_of(Numeric),
            document_type: document_type,
          )
        end

        it 'returns the expected response' do
          response = form.submit

          expect(response).to be_a_kind_of DocAuth::Response
          expect(response.success?).to eq(true)
          expect(response.doc_auth_success?).to eq(true)
          expect(response.selfie_check_performed?).to eq(true)
          expect(response.selfie_status).to eq(:success)
          expect(response.errors).to eq({})
          expect(response.attention_with_barcode?).to eq(false)
        end

        context 'the attempts_api_tracker is enabled' do
          let(:doc_escrow_enabled) { true }

          before do
            expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
            allow(writer).to receive(:write).exactly(3).times

            # testing that the storage is happening
            expect(writer).to receive(:write).with(image: form.send(:back_image_bytes))
              .and_return result
            expect(writer).to receive(:write).with(image: form.send(:front_image_bytes))
              .and_return result
            expect(writer).to receive(:write).with(image: form.send(:selfie_image_bytes))
              .and_return result
          end

          it 'tracks the event' do
            expect(attempts_api_tracker).to receive(:idv_document_uploaded).with(
              success: true,
              document_back_image_encryption_key: '12345',
              document_back_image_file_id: 'name',
              document_front_image_encryption_key: '12345',
              document_front_image_file_id: 'name',
              selfie_image_encryption_key: '12345',
              selfie_image_file_id: 'name',
              failure_reason: nil,
            )
            form.submit
          end
        end
      end

      context 'when acuant a/b test is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled)
            .and_return(true)
          allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_percent)
            .and_return(50)
        end

        it 'returns the expected response' do
          response = form.submit

          expect(response).to be_a_kind_of DocAuth::Response
          expect(response.success?).to eq(true)
          expect(response.doc_auth_success?).to eq(true)
          expect(response.selfie_status).to eq(:not_processed)
          expect(response.errors).to eq({})
          expect(response.attention_with_barcode?).to eq(false)
          expect(response.pii_from_doc).to eq(
            Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT),
          )
        end
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
        expect(response.pii_from_doc.to_h).to eq({})
      end
    end

    context 'invalid metadata shape' do
      let(:back_image_metadata) { '{' }

      it 'logs analytics excluding invalid metadata' do
        form.submit
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          submit_attempts: 1,
          remaining_submit_attempts: 3,
          user_id: document_capture_session.user.uuid,
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          liveness_checking_required: boolean,
          document_type: document_type,
        )
      end

      it 'returns the expected response' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq(Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT))
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

      it 'includes remaining_submit_attempts' do
        response = form.submit
        expect(response.extra[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
      end

      context 'the attempts_api_tracker is enabled' do
        let(:doc_escrow_enabled) { true }

        before do
          expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
          allow(writer).to receive(:write).exactly(3).times

          # testing that the storage is happening
          expect(writer).to receive(:write).with(image: form.send(:back_image_bytes))
            .and_return result
          expect(writer).to receive(:write).with(image: nil).and_call_original
          expect(writer).to receive(:write).with(image: nil).and_call_original
        end

        it 'tracks the event' do
          expect(attempts_api_tracker).to receive(:idv_document_uploaded).with(
            success: false,
            document_back_image_encryption_key: '12345',
            document_back_image_file_id: 'name',
            document_front_image_encryption_key: nil,
            document_front_image_file_id: nil,
            selfie_image_encryption_key: nil,
            selfie_image_file_id: nil,
            failure_reason: { front: [:blank] },
          )
          form.submit
        end
      end
    end

    context 'posting images to client fails' do
      let(:errors) do
        { front: 'glare' }
      end

      let(:failed_response) do
        DocAuth::Response.new(
          success: false,
          errors: errors,
          extra: {
            remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
            doc_auth_result: 'Failed',
          },
        )
      end
      let(:doc_auth_client) { double(DocAuth::LexisNexis::LexisNexisClient) }
      before do
        subject.instance_variable_set(:@doc_auth_client, doc_auth_client)
        allow(doc_auth_client).to receive(:post_images) { failed_response }
      end

      it 'is not successful' do
        response = form.submit

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(false)
        expect(response.doc_auth_success?).to eq(false)
        expect(response.selfie_status).to eq(:not_processed)
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.pii_from_doc).to eq(nil)
      end

      context 'the attempts_api_tracker is enabled' do
        let(:doc_escrow_enabled) { true }

        before do
          expect(EncryptedDocStorage::DocWriter).to receive(:new).and_return(writer)
          allow(writer).to receive(:write).exactly(3).times

          # testing that the storage is happening
          expect(writer).to receive(:write).with(image: form.send(:back_image_bytes))
            .and_return result
          expect(writer).to receive(:write).with(image: form.send(:front_image_bytes))
            .and_return result
          expect(writer).to receive(:write).with(image: nil).and_call_original
        end

        it 'tracks the event (as a success as doc upload succeeded)' do
          expect(attempts_api_tracker).to receive(:idv_document_uploaded).with(
            success: true,
            document_back_image_encryption_key: '12345',
            document_back_image_file_id: 'name',
            document_front_image_encryption_key: '12345',
            document_front_image_file_id: 'name',
            selfie_image_encryption_key: nil,
            selfie_image_file_id: nil,
            failure_reason: nil,
          )
          form.submit
        end
      end

      it 'saves the doc_auth_result to document_capture_session' do
        response = form.submit
        session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)

        expect(response).to be_a_kind_of DocAuth::Response
        expect(response.success?).to eq(false)
        expect(response.doc_auth_success?).to eq(false)
        expect(session.last_doc_auth_result).to eq('Failed')
      end

      it 'includes remaining_submit_attempts' do
        response = form.submit
        expect(response.extra[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
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

      it 'logs analytics event' do
        form.submit
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          hash_including(
            doc_auth_result: 'Failed',
            errors: { front: 'glare' },
            success: false,
            doc_type_supported: boolean,
            doc_auth_success: boolean,
            liveness_checking_required: boolean,
            selfie_status: :not_processed,
            selfie_live: boolean,
            selfie_quality_good: boolean,
          ),
        )
      end

      context 'selfie is checked for liveness' do
        let(:liveness_checking_required) { true }
        let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
        let(:errors) do
          { selfie: 'glare' }
        end
        let(:back_image) { DocAuthImageFixtures.portrait_match_fail_yaml }

        before do
          allow(failed_response).to receive(:doc_auth_success?).and_return(true)
          allow(failed_response).to receive(:selfie_status).and_return(:fail)
        end

        it 'includes client response errors' do
          response = form.submit
          expect(response.errors[:front]).to be_nil
          expect(response.errors[:back]).to be_nil
          expect(response.errors[:selfie]).to eq('glare')
        end

        it 'keeps fingerprints of failed image and triggers error when submit same image' do
          form.submit
          session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
          capture_result = session.load_result
          expect(capture_result.failed_front_image_fingerprints).to match_array([])
          expect(capture_result.failed_back_image_fingerprints).to match_array([])
          expect(capture_result.failed_selfie_image_fingerprints.length).to eq(1)
          response = form.submit
          expect(response.errors).to have_key(:selfie)
          expect(response.errors)
            .to have_value([I18n.t('doc_auth.errors.doc.resubmit_failed_image')])
        end
      end
    end

    context 'PII validation from client response fails' do
      let(:failed_response) do
        Idv::DocAuthFormResponse.new(
          success: false,
          errors: { doc_pii: 'bad' },
          extra: {
            pii_like_keypaths: pii_like_keypaths_state_id,
            attention_with_barcode: false,
            id_issued_status: 'missing',
            id_expiration_status: 'missing',
            passport_issued_status: 'missing',
            passport_expiration_status: 'missing',
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

      it 'includes remaining_submit_attempts' do
        response = form.submit
        expect(response.extra[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
      end

      it 'includes doc_pii errors' do
        response = form.submit
        expect(response.errors[:doc_pii]).to eq('bad')
      end

      it 'keeps fingerprints of failed image and triggers error when submit same image' do
        form.submit
        session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
        capture_result = session.load_result
        expect(capture_result.failed_front_image_fingerprints.length).to eq(1)
        expect(capture_result.failed_back_image_fingerprints.length).to eq(1)
        response = form.submit
        expect(response.errors).to have_key(:front)
        expect(response.errors).to have_value([I18n.t('doc_auth.errors.doc.resubmit_failed_image')])
        expect(fake_analytics).to have_logged_event(
          'IdV: failed doc image resubmitted',
          submit_attempts: 1,
          remaining_submit_attempts: 3,
          user_id: document_capture_session.user.uuid,
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          liveness_checking_required: boolean,
          side: 'both',
          document_type: document_type,
        )
      end

      context 'when selfie is checked for liveness' do
        let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
        let(:back_image) { DocAuthImageFixtures.portrait_match_success_yaml }
        it 'keeps fingerprints of failed image and triggers error when submit same image' do
          form.submit
          session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
          capture_result = session.load_result
          expect(capture_result.failed_front_image_fingerprints.length).to eq(1)
          expect(capture_result.failed_back_image_fingerprints.length).to eq(1)
          expect(capture_result.failed_selfie_image_fingerprints).to be_nil
          response = form.submit
          expect(response.errors).to have_key(:front)
          expect(response.errors).to have_key(:back)
          expect(response.errors)
            .to have_value([I18n.t('doc_auth.errors.doc.resubmit_failed_image')])
          expect(fake_analytics).to have_logged_event(
            'IdV: failed doc image resubmitted',
            submit_attempts: 1,
            remaining_submit_attempts: 3,
            user_id: document_capture_session.user.uuid,
            front_image_fingerprint: an_instance_of(String),
            back_image_fingerprint: an_instance_of(String),
            liveness_checking_required: boolean,
            side: 'both',
            document_type: document_type,
          )
        end
      end
    end

    context 'Passport MRZ validation fails' do
      let(:passport_pii_response) do
        DocAuth::Response.new(
          success: true,
          errors: {},
          extra: {},
          pii_from_doc: Pii::Passport.new(**Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT),
        )
      end

      let(:failed_passport_mrz_response) do
        DocAuth::Response.new(
          success: false,
          errors: { passport: 'invalid MRZ' },
          extra: {
            vendor: 'DoS',
            correlation_id_sent: 'something',
            correlation_id_received: 'something else',
            response: 'NO',
          },
        )
      end

      let(:response) { form.submit }

      before do
        allow_any_instance_of(described_class)
          .to receive(:post_images_to_client)
          .and_return(passport_pii_response)

        allow_any_instance_of(DocAuth::Dos::Requests::MrzRequest)
          .to receive(:fetch)
          .and_return(failed_passport_mrz_response)
      end

      it 'is not successful' do
        expect(response.success?).to eq(false)
      end

      it 'includes remaining_submit_attempts' do
        expect(response.extra[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
      end

      it 'includes mrz errors' do
        expect(response.errors).to eq({ passport: 'invalid MRZ' })
      end

      it 'logs the check event' do
        response

        expect(fake_analytics).to have_logged_event(
          :idv_dos_passport_verification,
          success: false,
          response: 'NO',
          submit_attempts: 1,
          remaining_submit_attempts: 3,
          user_id: document_capture_session.user.uuid,
          document_type: document_type,
        )
      end
    end

    context 'Passport MRZ validation succeeds' do
      let(:passport_pii_response) do
        DocAuth::Response.new(
          success: true,
          errors: {},
          extra: {},
          pii_from_doc: Pii::Passport.new(**Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT),
        )
      end

      let(:successful_passport_mrz_response) do
        DocAuth::Response.new(
          success: true,
          errors: {},
          extra: {
            vendor: 'DoS',
            correlation_id_sent: 'something',
            correlation_id_received: 'something else',
            response: 'YES',
          },
        )
      end

      let(:response) { form.submit }

      before do
        allow_any_instance_of(described_class)
          .to receive(:post_images_to_client)
          .and_return(passport_pii_response)

        allow_any_instance_of(DocAuth::Dos::Requests::MrzRequest)
          .to receive(:fetch)
          .and_return(successful_passport_mrz_response)
      end

      it 'is successful' do
        expect(response.success?).to eq(true)
      end

      it 'logs the check event' do
        response

        expect(fake_analytics).to have_logged_event(
          :idv_dos_passport_verification,
          success: true,
          response: 'YES',
          submit_attempts: 1,
          remaining_submit_attempts: 3,
          user_id: document_capture_session.user.uuid,
          document_type: document_type,
        )
      end
    end

    describe 'image source' do
      let(:source) { nil }
      let(:front_image_metadata) do
        { width: 40, height: 40, mimeType: 'image/png', source: source }.compact
      end
      let(:back_image_metadata) do
        { width: 20, height: 20, mimeType: 'image/png', source: source }.compact
      end
      let(:image_source) { nil }
      let(:images_cropped) { false }

      before do
        expect_any_instance_of(DocAuth::Mock::DocAuthMockClient)
          .to receive(:post_images)
          .with(hash_including(image_source: image_source, images_cropped: images_cropped))
          .and_call_original
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
          { width: 20, height: 20, mimeType: 'image/png', source: 'acuant' }
        end
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          form.submit
        end
      end

      context 'acuant images' do
        let(:source) { 'acuant' }
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }

        context 'when both images are captured via autocapture' do
          let(:images_cropped) { true }
          before do
            front_image_metadata[:acuantCaptureMode] = 'AUTO'
            back_image_metadata[:acuantCaptureMode] = 'AUTO'
          end

          it 'sets image source to acuant sdk' do
            form.submit
          end
        end

        context 'selfie is submitted' do
          let(:liveness_checking_required) { true }
          let(:selfie_image) { DocAuthImageFixtures.selfie_image_multipart }
          context 'captured with acuant sdk' do
            let(:selfie_image_metadata) do
              { width: 10, height: 10, mimeType: 'image/png', source: source }
            end

            before do
              front_image_metadata.merge!(acuantCaptureMode: 'AUTO')
            end

            it 'sets image source to acuant sdk' do
              form.submit
            end
          end

          context 'add using file upload' do
            let(:selfie_image_metadata) do
              { width: 10, height: 10, mimeType: 'image/png', source: 'upload' }
            end

            before do
              back_image_metadata.merge!(acuantCaptureMode: 'AUTO')
            end

            it 'sets image source to acuant sdk' do
              form.submit
            end
          end
        end
      end

      context 'malformed image metadata' do
        let(:source) { 'upload' }
        let(:front_image_metadata) { nil }
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
          allow(client_response).to receive(:doc_auth_success?).and_return(false)
          allow(client_response).to receive(:selfie_status).and_return(:not_processed)
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
          allow(client_response).to receive(:doc_auth_success?).and_return(false)
          allow(client_response).to receive(:selfie_status).and_return(:not_processed)
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
          allow(client_response).to receive(:doc_auth_success?).and_return(false)
          allow(client_response).to receive(:selfie_status).and_return(:not_processed)
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
          allow(client_response).to receive(:doc_auth_success?).and_return(false)
          allow(doc_pii_response).to receive(:success?).and_return(false)
          allow(client_response).to receive(:selfie_status).and_return(:not_processed)
          form.send(:validate_form)
          capture_result = form.send(:store_failed_images, client_response, doc_pii_response)
          expect(capture_result[:front]).not_to be_empty
          expect(capture_result[:back]).not_to be_empty
        end
      end
    end
  end
end
