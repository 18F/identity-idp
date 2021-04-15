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
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    before do
      Funnel::DocAuth::RegisterStep.new(user.id, '').call('welcome', :view, true)
    end

    context 'when fields are missing' do
      before { params.delete(:front) }

      it 'returns error status when not provided image fields' do
        action

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
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        expect(@analytics).not_to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          any_args,
        )

        action

        expect_funnel_update_counts(user, 0)
      end
    end

    context 'when a value is not a file' do
      before { params.merge!(front: 'some string') }

      it 'returns an error' do
        action

        expect(response.status).to eq(400)
        expect(json[:errors]).to eq [
          { field: 'front', message: I18n.t('doc_auth.errors.not_a_file') },
        ]
      end

      context 'with a locale param' do
        before { params.merge!(locale: 'es') }

        it 'translates errors using the locale param' do
          action

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
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        expect(@analytics).not_to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          any_args,
        )

        action

        expect_funnel_update_counts(user, 0)
      end
    end

    context 'when document capture session is invalid' do
      it 'returns error status when document_capture_session is not provided' do
        params.delete(:document_capture_session_uuid)
        action

        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:errors]).to eq [
          { field: 'document_capture_session', message: 'Please fill in this field.' },
        ]
      end

      it 'returns error status when document_capture_session is invalid' do
        params[:document_capture_session_uuid] = 'bad uuid'
        action

        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:errors]).to eq [
          { field: 'document_capture_session', message: 'Please fill in this field.' },
        ]
      end
    end

    context 'throttling' do
      it 'returns remaining_attempts with error' do
        params.delete(:front)
        allow(Throttler::RemainingCount).to receive(:call).and_return(3)

        action

        expect(response.status).to eq(400)
        expect(json).to eq(
          {
            success: false,
            errors: [{ field: 'front', message: 'Please fill in this field.' }],
            remaining_attempts: 3,
          },
        )
      end

      it 'returns an error when throttled' do
        allow(Throttler::IsThrottledElseIncrement).to receive(:call).once.and_return(true)
        allow(Throttler::RemainingCount).to receive(:call).and_return(0)

        action

        expect(response.status).to eq(429)
        expect(json).to eq(
          {
            success: false,
            redirect: idv_session_errors_throttled_url,
          },
        )
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
          user_id: user.uuid,
          remaining_attempts: 0,
        )

        expect(@analytics).not_to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          any_args,
        )

        action

        expect_funnel_update_counts(user, 0)
      end
    end

    context 'when image upload succeeds' do
      it 'returns a successful response and modifies the session' do
        action

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
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          success: true,
          errors: {},
          billed: true,
          exception: nil,
          result: 'Passed',
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
          success: true,
          errors: {},
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        action

        expect_funnel_update_counts(user, 1)
      end

      context 'but doc_pii validation fails' do
        let(:first_name) { 'FAKEY' }
        let(:last_name) { 'MCFAKERSON' }
        let(:state) { 'ND' }
        let(:dob) { '10/06/1938' }

        before do
          IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
            method: :get_results,
            response: IdentityDocAuth::Response.new(
              success: true,
              errors: {},
              extra: { result: 'Passed', billed: true },
              pii_from_doc: {
                first_name: first_name,
                last_name: last_name,
                state: state,
                dob: dob,
              },
            ),
          )
        end

        context 'due to invalid Name' do
          let(:first_name) { nil }

          it 'tracks name validation errors in analytics' do
            stub_analytics

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
              success: true,
              errors: {},
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
              success: true,
              errors: {},
              billed: true,
              exception: nil,
              result: 'Passed',
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.alerts.full_name_check')],
              },
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            action
          end
        end

        context 'due to invalid State' do
          let(:state) { 'Maryland' }

          it 'tracks state validation errors in analytics' do
            stub_analytics

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
              success: true,
              errors: {},
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
              success: true,
              errors: {},
              billed: true,
              exception: nil,
              result: 'Passed',
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            action
          end
        end

        context 'but doc_pii validation fails due to invalid DOB' do
          let(:dob) { nil }

          it 'tracks dob validation errors in analytics' do
            stub_analytics

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
              success: true,
              errors: {},
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
              success: true,
              errors: {},
              billed: true,
              exception: nil,
              result: 'Passed',
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.alerts.birth_date_checks')],
              },
              user_id: user.uuid,
              remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
            )

            action
          end
        end
      end
    end

    context 'when image upload fails' do
      before do
        IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_images,
          response: IdentityDocAuth::Response.new(
            success: false,
            errors: { front: ['Too blurry', 'Wrong document'] },
          ),
        )
      end

      it 'returns an error response' do
        action

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
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          success: false,
          errors: {
            front: ['Too blurry', 'Wrong document'],
          },
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
          exception: nil,
        )

        action

        expect_funnel_update_counts(user, 1)
      end
    end

    context 'when a value is an error-formatted yaml file' do
      before { params.merge!(back: DocAuthImageFixtures.error_yaml_multipart) }

      it 'returns error from yaml file' do
        action

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
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
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
          user_id: user.uuid,
          remaining_attempts: IdentityConfig.store.acuant_max_attempts - 1,
        )

        action

        expect_funnel_update_counts(user, 1)
      end
    end

    context 'when required pii field is missing from doc response' do
      before { params.merge!(back: DocAuthImageFixtures.error_yaml_no_db_multipart) }

      it 'returns error' do
        action

        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:remaining_attempts]).to be_a_kind_of(Numeric)
        expect(json[:errors]).to eq [
          {
            field: 'pii',
            message: I18n.t('doc_auth.errors.alerts.birth_date_checks'),
          },
        ]
      end
    end
  end

  def expect_funnel_update_counts(user, count)
    doc_auth_log = DocAuthLog.where(user_id: user.id).first
    expect(doc_auth_log.back_image_submit_count).to eq(count)
    expect(doc_auth_log.front_image_submit_count).to eq(count)
  end
end
