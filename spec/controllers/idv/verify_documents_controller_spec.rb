require 'rails_helper'

describe Idv::VerifyDocumentsController do
  describe '#create' do
    before do
      sign_in_as_user
      controller.current_user.document_capture_sessions.create!
    end

    subject(:action) { post :create, params: params }

    let(:document_capture_session) { controller.current_user.document_capture_sessions.last }
    let(:params) do
      {
        encryption_key: 'foo',
        front_image_url: 'http://foo.com/bar1',
        back_image_url: 'http://foo.com/bar2',
        selfie_image_url: 'http://foo.com/bar3',
        document_capture_session_uuid: document_capture_session.uuid,
      }
    end

    context 'when document capture is not enabled' do
      before do
        allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(false)
      end

      it 'disables the endpoint' do
        action
        expect(response).to be_not_found
      end
    end

    context 'when document capture is enabled' do
      before do
        allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(true)
      end

      context 'when fields are missing' do
        before { params.delete(:front_image_url) }

        it 'returns error status when not provided image fields' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json[:success]).to eq(false)
          expect(json[:errors]).to eq [
            { field: 'front_image_url', message: I18n.t('doc_auth.errors.not_a_file') },
          ]
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
            success: false,
            errors: {
              front_image_url: [I18n.t('doc_auth.errors.not_a_file')],
            },
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).not_to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            any_args,
          )

          action
        end
      end

      context 'when a value is not a url' do
        before { params.merge!(front_image_url: 'some string') }

        it 'returns an error' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json[:errors]).to eq [
            { field: 'front_image_url', message: I18n.t('doc_auth.errors.not_a_file') },
          ]
        end

        context 'with a locale param' do
          before { params.merge!(locale: 'es') }

          it 'translates errors using the locale param' do
            action

            json = JSON.parse(response.body, symbolize_names: true)
            expect(response.status).to eq(400)
            expect(json[:errors]).to eq [
              { field: 'front_image_url', message: I18n.t('doc_auth.errors.not_a_file',
                                                          locale: 'es') },
            ]
          end
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
            success: false,
            errors: {
              front_image_url: [I18n.t('doc_auth.errors.not_a_file')],
            },
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).not_to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            any_args,
          )

          action
        end
      end

      context 'throttling' do
        it 'returns remaining_attempts with error' do
          params.delete(:front_image_url)
          allow(Throttler::RemainingCount).to receive(:call).and_return(3)

          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json).to eq({
                               success: false,
                               errors: [{ field: 'front_image_url',
                                          message: I18n.t('doc_auth.errors.not_a_file') }],
                               remaining_attempts: 3,
                             })
        end

        it 'returns an error when throttled' do
          allow(Throttler::IsThrottledElseIncrement).to receive(:call).once.and_return(true)
          allow(Throttler::RemainingCount).to receive(:call).and_return(0)

          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(429)
          expect(json).to eq({
                               success: false,
                               redirect: idv_session_errors_throttled_url,
                             })
        end

        it 'tracks analytics' do
          allow(Throttler::IsThrottledElseIncrement).to receive(:call).once.and_return(true)
          allow(Throttler::RemainingCount).to receive(:call).and_return(0)

          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
            success: false,
            errors: {
              limit: [I18n.t('errors.doc_auth.acuant_throttle')],
            },
            remaining_attempts: 0,
          )

          expect(@analytics).not_to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            any_args,
          )

          action
        end
      end

      context 'when document verification submission succeeds' do
        it 'returns a successful response' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(200)
          expect(json[:success]).to eq(true)
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
            success: true,
            errors: {},
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: true,
            errors: {},
          )

          action
        end
      end

      context 'when document verification submission fails' do
        before do
          allow(VendorDocumentVerificationJob).to receive(:perform).
            and_return(FormResponse.new(success: false,
                                        errors: { front_image_url: ['Could not read file'] }))
        end

        it 'returns an error response' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json[:success]).to eq(false)
          expect(json[:remaining_attempts]).to be_a_kind_of(Numeric)
          expect(json[:errors]).to eq [
            { field: 'front_image_url', message: 'Could not read file' },
          ]
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
            success: false,
            errors: {},
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: false,
            errors: {
              front_image_url: ['Could not read file'],
            },
            exception: nil,
          )

          action
        end
      end

      context 'when a value is an error-formatted yaml file' do
        before { params.merge!(back: DocAuthImageFixtures.error_yaml_multipart) }

        it 'returns error from yaml file' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:remaining_attempts]).to be_a_kind_of(Numeric)
          expect(json[:errors]).to eq [
            {
              field: 'results',
              message: I18n.t('friendly_errors.doc_auth.barcode_could_not_be_read'),
            },
          ]
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
            success: true,
            errors: {},
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: false,
            errors: {
              results: [I18n.t('friendly_errors.doc_auth.barcode_could_not_be_read')],
            },
            billed: true,
            result: 'Caution',
            exception: nil,
          )

          action
        end
      end
    end
  end

  describe '#show' do
    before do
      sign_in_as_user
      controller.current_user.document_capture_sessions.create!
    end

    subject(:action) { get :show, params: params }

    let(:document_capture_session) { controller.current_user.document_capture_sessions.last }
    let(:params) do
      {
        document_capture_session_uuid: document_capture_session.uuid,
      }
    end

    context 'when document capture is not enabled' do
      before do
        allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(false)
      end

      it 'disables the endpoint' do
        action
        expect(response).to be_not_found
      end
    end

    context 'when document capture is enabled' do
      before do
        allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(true)
      end

      it 'returns error status when not provided image fields' do
        action

        json = JSON.parse(response.body, symbolize_names: true)
        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:errors]).to eq [{ field: 'front_image_url',
                                       message: I18n.t('doc_auth.errors.not_a_file') }]
      end

      it 'tracks analytics' do
        stub_analytics

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
          success: false,
          errors: {
            front_image_url: [I18n.t('doc_auth.errors.not_a_file')],
          },
          remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
        )

        expect(@analytics).not_to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          any_args,
        )

        action
      end
    end
  end
end
