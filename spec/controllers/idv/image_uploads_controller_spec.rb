require 'rails_helper'

describe Idv::ImageUploadsController do
  describe '#create' do
    subject(:action) { post :create, params: params }

    let(:user) { create(:user) }
    let!(:document_capture_session) { user.document_capture_sessions.create! }
    let(:params) do
      {
        front: DocAuthImageFixtures.document_front_image_multipart,
        back: DocAuthImageFixtures.document_back_image_multipart,
        selfie: DocAuthImageFixtures.selfie_image_multipart,
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
        before { params.delete(:front) }

        it 'returns error status when not provided image fields' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json[:success]).to eq(false)
          expect(json[:errors]).to eq [
            { field: 'front', message: 'Please fill in this field.' },
          ]
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
            success: false,
            errors: {
              front: ['Please fill in this field.'],
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

      context 'when a value is not a file' do
        before { params.merge!(front: 'some string') }

        it 'returns an error' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json[:errors]).to eq [
            { field: 'front', message: I18n.t('doc_auth.errors.not_a_file') },
          ]
        end

        context 'with a locale param' do
          before { params.merge!(locale: 'es') }

          it 'translates errors using the locale param' do
            action

            json = JSON.parse(response.body, symbolize_names: true)
            expect(response.status).to eq(400)
            expect(json[:errors]).to eq [
              { field: 'front', message: I18n.t('doc_auth.errors.not_a_file', locale: 'es') },
            ]
          end
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
            success: false,
            errors: {
              front: [I18n.t('doc_auth.errors.not_a_file')],
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
          params.delete(:front)
          allow(Throttler::RemainingCount).to receive(:call).and_return(3)

          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json).to eq({
                               success: false,
                               errors: [{ field: 'front', message: 'Please fill in this field.' }],
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
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
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

      context 'when image upload succeeds' do
        it 'returns a successful response and modifies the session' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(200)
          expect(json[:success]).to eq(true)
          expect(document_capture_session.reload.load_result.success?).to eq(true)
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
            success: true,
            errors: {},
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: true,
            errors: {},
            billed: true,
            exception: nil,
            result: 'Passed',
          )

          action
        end
      end

      context 'when image upload fails' do
        before do
          DocAuth::Mock::DocAuthMockClient.mock_response!(
            method: :post_images,
            response: DocAuth::Response.new(
              success: false,
              errors: { front: ['Too blurry', 'Wrong document'] },
            ),
          )
        end

        it 'returns an error response' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(response.status).to eq(400)
          expect(json[:success]).to eq(false)
          expect(json[:remaining_attempts]).to be_a_kind_of(Numeric)
          expect(json[:errors]).to eq [
            { field: 'front', message: 'Too blurry' },
            { field: 'front', message: 'Wrong document' },
          ]
        end

        it 'tracks analytics' do
          stub_analytics

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
            success: true,
            errors: {},
            remaining_attempts: Figaro.env.acuant_max_attempts.to_i - 1,
          )

          expect(@analytics).to receive(:track_event).with(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: false,
            errors: {
              front: ['Too blurry', 'Wrong document'],
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
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
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
end
