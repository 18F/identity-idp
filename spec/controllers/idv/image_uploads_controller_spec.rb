require 'rails_helper'

describe Idv::ImageUploadsController do
  describe '#create' do
    subject(:action) { post :create, params: params }

    let(:user) { create(:user) }
    let!(:document_capture_session) { user.document_capture_sessions.create!(user: user) }
    let(:params) do
      {
        front: DocAuthImageFixtures.document_front_image_multipart,
        front_image_metadata: '{"glare":99.99}',
        back: DocAuthImageFixtures.document_back_image_multipart,
        back_image_metadata: '{"glare":99.99}',
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
          error_details: {
            front: [:blank],
          },
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
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
          error_details: {
            front: [I18n.t('doc_auth.errors.not_a_file')],
          },
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
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
        create(
          :throttle,
          :with_throttled,
          attempts: IdentityConfig.store.doc_auth_max_attempts - 4,
          user: user,
          throttle_type: :idv_doc_auth,
        )

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
        create(:throttle, :with_throttled, user: user, throttle_type: :idv_doc_auth)

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
        create(
          :throttle,
          :with_throttled,
          attempts: IdentityConfig.store.doc_auth_max_attempts,
          user: user,
          throttle_type: :idv_doc_auth,
        )

        stub_analytics

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM,
          success: false,
          errors: {
            limit: [I18n.t('errors.doc_auth.throttled_heading')],
          },
          error_details: {
            limit: [I18n.t('errors.doc_auth.throttled_heading')],
          },
          user_id: user.uuid,
          attempts: IdentityConfig.store.doc_auth_max_attempts,
          remaining_attempts: 0,
          pii_like_keypaths: [[:pii]],
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
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          success: true,
          errors: {},
          async: false,
          billed: true,
          exception: nil,
          doc_auth_result: 'Passed',
          state: 'MT',
          state_id_type: 'drivers_license',
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          pii_like_keypaths: [[:pii]],
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
          success: true,
          errors: {},
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
        )

        action

        expect_funnel_update_counts(user, 1)
      end

      context 'but doc_pii validation fails' do
        let(:first_name) { 'FAKEY' }
        let(:last_name) { 'MCFAKERSON' }
        let(:state) { 'ND' }
        let(:state_id_type) { 'drivers_license' }
        let(:dob) { '10/06/1938' }

        before do
          DocAuth::Mock::DocAuthMockClient.mock_response!(
            method: :get_results,
            response: DocAuth::Response.new(
              success: true,
              errors: {},
              extra: { doc_auth_result: 'Passed', billed: true },
              pii_from_doc: {
                first_name: first_name,
                last_name: last_name,
                state: state,
                state_id_type: state_id_type,
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
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
              success: true,
              errors: {},
              async: false,
              billed: true,
              exception: nil,
              doc_auth_result: 'Passed',
              state: 'ND',
              state_id_type: 'drivers_license',
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              pii_like_keypaths: [[:pii]],
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.alerts.full_name_check')],
              },
              error_details: {
                pii: [I18n.t('doc_auth.errors.alerts.full_name_check')],
              },
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
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
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
              success: true,
              errors: {},
              async: false,
              billed: true,
              exception: nil,
              doc_auth_result: 'Passed',
              state: 'Maryland',
              state_id_type: 'drivers_license',
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              pii_like_keypaths: [[:pii]],
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              error_details: {
                pii: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
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
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
              success: true,
              errors: {},
              async: false,
              billed: true,
              exception: nil,
              doc_auth_result: 'Passed',
              state: 'ND',
              state_id_type: 'drivers_license',
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              pii_like_keypaths: [[:pii]],
            )

            expect(@analytics).to receive(:track_event).with(
              Analytics::IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION,
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.alerts.birth_date_checks')],
              },
              error_details: {
                pii: [I18n.t('doc_auth.errors.alerts.birth_date_checks')],
              },
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
            )

            action
          end
        end
      end
    end

    context 'when image upload fails' do
      before do
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_images,
          response: DocAuth::Response.new(
            success: false,
            errors: { front: [DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES] },
          ),
        )
      end

      it 'returns an error response' do
        action

        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:remaining_attempts]).to be_a_kind_of(Numeric)
        expect(json[:errors]).to eq [
          {
            field: 'front',
            message: 'We couldn’t verify the front of your ID. Try taking a new picture.',
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
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          success: false,
          errors: {
            front: [I18n.t('doc_auth.errors.general.multiple_front_id_failures')],
          },
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          state: nil,
          state_id_type: nil,
          exception: nil,
          async: false,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          pii_like_keypaths: [[:pii]],
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
            field: 'back',
            message: I18n.t('doc_auth.errors.alerts.barcode_content_check'),
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
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
        )

        expect(@analytics).to receive(:track_event).with(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          success: false,
          errors: {
            back: [I18n.t('doc_auth.errors.alerts.barcode_content_check')],
          },
          async: false,
          billed: true,
          doc_auth_result: 'Caution',
          state: nil,
          state_id_type: nil,
          exception: nil,
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          pii_like_keypaths: [[:pii]],
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
