require 'rails_helper'

describe Idv::ImageUploadsController do
  let(:document_filename_regex) { /^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\.[a-z]+$/ }
  let(:base64_regex) { /^[a-z0-9+\/]+=*$/i }

  describe '#create' do
    subject(:action) do
      post :create, params: params
    end

    let(:user) { create(:user) }
    let!(:document_capture_session) { user.document_capture_sessions.create!(user: user) }
    let(:params) do
      {
        front: DocAuthImageFixtures.document_front_image_multipart,
        front_image_metadata: '{"glare":99.99}',
        back: DocAuthImageFixtures.document_back_image_multipart,
        back_image_metadata: '{"glare":99.99}',
        document_capture_session_uuid: document_capture_session.uuid,
        flow_path: 'standard',
      }
    end
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    let(:store_encrypted_images) { false }

    before do
      allow(controller).to receive(:store_encrypted_images?).and_return(store_encrypted_images)
    end

    before do
      Funnel::DocAuth::RegisterStep.new(user.id, '').call('welcome', :view, true)
      allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
        and_return(false)
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

      it 'tracks events' do
        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload form submitted,',
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
          flow_path: 'standard',
        ).exactly(0).times

        expect(@analytics).not_to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
          any_args,
        )

        expect(@irs_attempts_api_tracker).not_to receive(:track_event).with(
          :idv_document_upload_submitted,
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

      it 'tracks events' do
        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload form submitted',
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
          flow_path: 'standard',
        )

        expect(@irs_attempts_api_tracker).not_to receive(:track_event).with(
          :idv_document_upload_submitted,
          any_args,
        )

        expect(@analytics).not_to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
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
        Throttle.new(throttle_type: :idv_doc_auth, user: user).increment!

        action

        expect(response.status).to eq(400)
        expect(json).to eq(
          {
            success: false,
            errors: [{ field: 'front', message: 'Please fill in this field.' }],
            remaining_attempts: Throttle.max_attempts(:idv_doc_auth) - 2,
            result_failed: false,
            ocr_pii: nil,
          },
        )
      end

      it 'returns an error when throttled' do
        Throttle.new(throttle_type: :idv_doc_auth, user: user).increment_to_throttled!

        action

        expect(response.status).to eq(429)
        expect(json).to eq(
          {
            success: false,
            errors: [{ field: 'limit', message: 'We could not verify your ID' }],
            redirect: idv_session_errors_throttled_url,
            remaining_attempts: 0,
            result_failed: false,
            ocr_pii: nil,
          },
        )
      end

      it 'tracks events' do
        Throttle.new(throttle_type: :idv_doc_auth, user: user).increment_to_throttled!

        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload form submitted',
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
          flow_path: 'standard',
        )

        expect(@irs_attempts_api_tracker).not_to receive(:track_event).with(
          :idv_document_upload_submitted,
          any_args,
        )

        expect(@analytics).not_to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
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

      it 'tracks events' do
        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
          flow_path: 'standard',
        )

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
          success: true,
          errors: {},
          attention_with_barcode: false,
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
          flow_path: 'standard',
          vendor_workflow: 'unknown',
        )

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload vendor pii validation',
          success: true,
          errors: {},
          attention_with_barcode: false,
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
          flow_path: 'standard',
        )

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :idv_document_upload_submitted,
          success: true,
          failure_reason: nil,
          document_back_image_filename: nil,
          document_front_image_filename: nil,
          document_image_encryption_key: nil,
          document_state: 'MT',
          document_number: '1111111111111',
          document_issued: '2019-12-31',
          document_expiration: '2099-12-31',
          first_name: 'FAKEY',
          last_name: 'MCFAKERSON',
          date_of_birth: '1938-10-06',
          address: '1 FAKE RD',
        )

        action

        expect_funnel_update_counts(user, 1)
      end

      context 'encrypted document storage is enabled' do
        let(:store_encrypted_images) { true }

        it 'includes image fields in attempts api event' do
          stub_attempts_tracker

          expect(@irs_attempts_api_tracker).to receive(:track_event).with(
            :idv_document_upload_submitted,
            hash_including(
              success: true,
              failure_reason: nil,
              document_back_image_filename: match(document_filename_regex),
              document_front_image_filename: match(document_filename_regex),
              document_image_encryption_key: match(base64_regex),
            ),
          )

          action
        end
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

        context 'encrypted document storage is enabled' do
          let(:store_encrypted_images) { true }
          let(:first_name) { nil }

          it 'includes image references in attempts api' do
            stub_attempts_tracker

            expect(@irs_attempts_api_tracker).to receive(:track_event).with(
              :idv_document_upload_submitted,
              success: true,
              failure_reason: nil,
              document_state: 'ND',
              document_number: nil,
              document_issued: nil,
              document_expiration: nil,
              first_name: nil,
              last_name: 'MCFAKERSON',
              date_of_birth: '10/06/1938',
              address: nil,
              document_back_image_filename: match(document_filename_regex),
              document_front_image_filename: match(document_filename_regex),
              document_image_encryption_key: match(base64_regex),
            )

            action
          end
        end

        context 'due to invalid Name' do
          let(:first_name) { nil }

          it 'tracks name validation errors in analytics' do
            stub_analytics
            stub_attempts_tracker

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
              flow_path: 'standard',
            )

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload vendor submitted',
              success: true,
              errors: {},
              attention_with_barcode: false,
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
              flow_path: 'standard',
              vendor_workflow: 'unknown',
            )

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.alerts.full_name_check')],
              },
              error_details: {
                pii: [I18n.t('doc_auth.errors.alerts.full_name_check')],
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
              flow_path: 'standard',
            )

            expect(@irs_attempts_api_tracker).to receive(:track_event).with(
              :idv_document_upload_submitted,
              success: true,
              failure_reason: nil,
              document_state: 'ND',
              document_number: nil,
              document_issued: nil,
              document_expiration: nil,
              first_name: nil,
              last_name: 'MCFAKERSON',
              date_of_birth: '10/06/1938',
              address: nil,
              document_back_image_filename: nil,
              document_front_image_filename: nil,
              document_image_encryption_key: nil,
            )

            action
          end
        end

        context 'due to invalid State' do
          let(:state) { 'Maryland' }

          it 'tracks state validation errors in analytics' do
            stub_analytics
            stub_attempts_tracker

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
              flow_path: 'standard',
            )

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload vendor submitted',
              success: true,
              errors: {},
              attention_with_barcode: false,
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
              flow_path: 'standard',
              vendor_workflow: 'unknown',
            )

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              error_details: {
                pii: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
              flow_path: 'standard',
            )

            expect(@irs_attempts_api_tracker).to receive(:track_event).with(
              :idv_document_upload_submitted,
              success: true,
              failure_reason: nil,
              document_state: 'Maryland',
              document_number: nil,
              document_issued: nil,
              document_expiration: nil,
              first_name: 'FAKEY',
              last_name: 'MCFAKERSON',
              date_of_birth: '10/06/1938',
              address: nil,
              document_back_image_filename: nil,
              document_front_image_filename: nil,
              document_image_encryption_key: nil,
            )

            action
          end
        end

        context 'but doc_pii validation fails due to invalid DOB' do
          let(:dob) { nil }

          it 'tracks dob validation errors in analytics' do
            stub_analytics
            stub_attempts_tracker

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
              flow_path: 'standard',
            )

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload vendor submitted',
              success: true,
              errors: {},
              attention_with_barcode: false,
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
              flow_path: 'standard',
              vendor_workflow: 'unknown',
            )

            expect(@analytics).to receive(:track_event).with(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                pii: [I18n.t('doc_auth.errors.alerts.birth_date_checks')],
              },
              error_details: {
                pii: [I18n.t('doc_auth.errors.alerts.birth_date_checks')],
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              attempts: 1,
              remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              pii_like_keypaths: [[:pii]],
              flow_path: 'standard',
            )

            expect(@irs_attempts_api_tracker).to receive(:track_event).with(
              :idv_document_upload_submitted,
              success: true,
              failure_reason: nil,
              document_back_image_filename: nil,
              document_front_image_filename: nil,
              document_image_encryption_key: nil,
              document_state: 'ND',
              document_number: nil,
              document_issued: nil,
              document_expiration: nil,
              first_name: 'FAKEY',
              last_name: 'MCFAKERSON',
              date_of_birth: nil,
              address: nil,
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

      it 'tracks events' do
        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
          flow_path: 'standard',
        )

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
          success: false,
          errors: {
            front: [I18n.t('doc_auth.errors.general.multiple_front_id_failures')],
          },
          attention_with_barcode: false,
          user_id: user.uuid,
          attempts: 1,
          billed: nil,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          state: nil,
          state_id_type: nil,
          exception: nil,
          async: false,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          doc_auth_result: nil,
          pii_like_keypaths: [[:pii]],
          flow_path: 'standard',
          vendor_workflow: 'unknown',
        )

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :idv_document_upload_submitted,
          success: false,
          failure_reason: {
            front: [I18n.t('doc_auth.errors.general.multiple_front_id_failures')],
          },
          document_back_image_filename: nil,
          document_front_image_filename: nil,
          document_image_encryption_key: nil,
          document_state: nil,
          document_number: nil,
          document_issued: nil,
          document_expiration: nil,
          first_name: nil,
          last_name: nil,
          date_of_birth: nil,
          address: nil,
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
            field: 'general',
            message: I18n.t('doc_auth.errors.alerts.barcode_content_check'),
          }, {
            field: 'back',
            message: I18n.t('doc_auth.errors.general.fallback_field_level'),
          }
        ]
      end

      it 'tracks events' do
        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          user_id: user.uuid,
          attempts: 1,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          pii_like_keypaths: [[:pii]],
          flow_path: 'standard',
        )

        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
          success: false,
          errors: {
            general: [I18n.t('doc_auth.errors.alerts.barcode_content_check')],
            back: [I18n.t('doc_auth.errors.general.fallback_field_level')],
            hints: true,
          },
          attention_with_barcode: false,
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
          flow_path: 'standard',
          vendor_workflow: 'unknown',
        )

        expect(@irs_attempts_api_tracker).to receive(:track_event).with(
          :idv_document_upload_submitted,
          success: false,
          failure_reason: {
            general: [I18n.t('doc_auth.errors.alerts.barcode_content_check')],
            back: [I18n.t('doc_auth.errors.general.fallback_field_level')],
          },
          document_back_image_filename: nil,
          document_front_image_filename: nil,
          document_image_encryption_key: nil,
          document_state: nil,
          document_number: nil,
          document_issued: nil,
          document_expiration: nil,
          first_name: nil,
          last_name: nil,
          date_of_birth: nil,
          address: nil,
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

    context 'when the image was collected with the Acuant SDK' do
      before do
        stub_analytics
      end

      it 'logs the vendor workflow as NOCROPPING' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: doc auth image upload vendor submitted',
          success: true,
          errors: {},
          attention_with_barcode: false,
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
          flow_path: 'standard',
          vendor_workflow: 'unknown',
        )

        action
      end
    end
  end

  def expect_funnel_update_counts(user, count)
    doc_auth_log = DocAuthLog.where(user_id: user.id).first
    expect(doc_auth_log.back_image_submit_count).to eq(count)
    expect(doc_auth_log.front_image_submit_count).to eq(count)
  end
end
