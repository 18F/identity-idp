require 'rails_helper'

RSpec.describe Idv::ImageUploadsController, allowed_extra_analytics: [:*] do
  include DocPiiHelper

  let(:document_filename_regex) { /^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\.[a-z]+$/ }
  let(:base64_regex) { /^[a-z0-9+\/]+=*$/i }
  let(:back_image) { DocAuthImageFixtures.document_back_image_multipart }
  let(:selfie_img) { nil }
  let(:state_id_number) { 'S59397998' }

  describe '#create' do
    subject(:action) do
      post :create, params: params
    end

    let(:user) { create(:user) }
    let!(:document_capture_session) { user.document_capture_sessions.create!(user: user) }
    let(:flow_path) { 'standard' }
    let(:params) do
      {
        front: DocAuthImageFixtures.document_front_image_multipart,
        front_image_metadata: '{"glare":99.99}',
        back: back_image,
        selfie: selfie_img,
        back_image_metadata: '{"glare":99.99}',
        document_capture_session_uuid: document_capture_session.uuid,
        flow_path: flow_path,
      }.compact
    end
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

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

        action

        expect(@analytics).not_to have_logged_event(
          'IdV: doc auth image upload form submitted,',
        )

        expect(@analytics).not_to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
        )

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

        action

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: false,
          errors: {
            front: [I18n.t('doc_auth.errors.not_a_file')],
          },
          error_details: {
            front: { not_a_file: true },
          },
          user_id: user.uuid,
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          flow_path: 'standard',
          front_image_fingerprint: nil,
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          liveness_checking_required: boolean,
        )

        expect(@analytics).not_to have_logged_event('IdV: doc auth image upload vendor submitted')

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
      it 'returns remaining_submit_attempts with error' do
        params.delete(:front)
        RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user).increment!

        action

        expect(response.status).to eq(400)
        expect(json).to eq(
          {
            success: false,
            errors: [{ field: 'front', message: 'Please fill in this field.' }],
            remaining_submit_attempts: RateLimiter.max_attempts(:idv_doc_auth) - 2,
            result_code_invalid: true,
            result_failed: false,
            ocr_pii: nil,
            doc_type_supported: true,
            failed_image_fingerprints: { front: [], back: [], selfie: [] },
          },
        )
      end

      context 'when rate limited' do
        let(:redirect_url) { idv_session_errors_rate_limited_url }
        let(:error_json) do
          {
            success: false,
            errors: [{ field: 'limit', message: 'We couldn’t verify your ID' }],
            redirect: redirect_url,
            remaining_submit_attempts: 0,
            result_code_invalid: true,
            result_failed: false,
            ocr_pii: nil,
            doc_type_supported: true,
            failed_image_fingerprints: { front: [], back: [], selfie: [] },
          }
        end

        before do
          RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user).increment_to_limited!

          action
        end

        context 'hybrid flow' do
          let(:flow_path) { 'hybrid' }
          let(:redirect_url) { idv_hybrid_mobile_capture_complete_url }

          it 'returns an error and redirects to capture_complete on hybrid flow' do
            expect(response.status).to eq(429)
            expect(json).to eq(error_json)
          end
        end

        it 'redirects to session_errors_throttled on (mobile) standard flow' do
          expect(response.status).to eq(429)
          expect(json).to eq(error_json)
        end
      end

      it 'tracks events' do
        RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user).increment_to_limited!

        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: false,
          errors: {
            limit: [I18n.t('errors.doc_auth.rate_limited_heading')],
          },
          error_details: {
            limit: { rate_limited: true },
          },
          user_id: user.uuid,
          submit_attempts: IdentityConfig.store.doc_auth_max_attempts,
          remaining_submit_attempts: 0,
          flow_path: 'standard',
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          liveness_checking_required: boolean,
        )

        expect(@analytics).not_to have_logged_event('IdV: doc auth image upload vendor submitted')

        expect_funnel_update_counts(user, 0)
      end
    end

    context 'when image upload fails with 4xx status' do
      before do
        status = 440
        errors = { general: [DocAuth::Errors::IMAGE_SIZE_FAILURE],
                   front: [DocAuth::Errors::IMAGE_SIZE_FAILURE_FIELD] }
        message = [
          self.class.name,
          'Unexpected HTTP response',
          status,
        ].join(' ')
        exception = DocAuth::RequestError.new(message, status)
        response = DocAuth::Response.new(
          success: false,
          errors: errors,
          exception: exception,
          extra: { vendor: 'Mock' },
        )
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_front_image,
          response: response,
        )
      end

      it 'returns error response' do
        action
        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
        expect(json[:errors]).to eq [
          {
            field: 'general',
            message: I18n.t('doc_auth.errors.http.image_size.top_msg'),
          },
          {
            field: 'front',
            message: I18n.t('doc_auth.errors.http.image_size.failed_short'),
          },
        ]
      end
    end

    context 'when image upload succeeds' do
      # 50/50 state for selfie_check_performed in redis
      # fake up a response and verify that selfie_check_performed flows through?

      context 'selfie included' do
        let(:back_image) { DocAuthImageFixtures.portrait_match_success_yaml }
        let(:selfie_img) { DocAuthImageFixtures.selfie_image_multipart }

        before do
          resolved_authn_context_result = Vot::Parser.new(vector_of_trust: 'Pb').parse

          allow(controller).to receive(:resolved_authn_context_result).
            and_return(resolved_authn_context_result)
        end

        it 'returns a successful response and modifies the session' do
          expect_any_instance_of(DocAuth::Mock::DocAuthMockClient).
            to receive(:post_images).with(
              front_image: an_instance_of(String),
              back_image: an_instance_of(String),
              selfie_image: an_instance_of(String),
              image_source: :unknown,
              user_uuid: an_instance_of(String),
              uuid_prefix: nil,
              liveness_checking_required: true,
              images_cropped: false,
            ).and_call_original

          action

          expect(response.status).to eq(200)
          expect(json[:success]).to eq(true)
          expect(document_capture_session.reload.load_result.success?).to eq(true)
          expect(document_capture_session.reload.load_result.selfie_check_performed?).to eq(true)
        end
      end

      it 'returns a successful response and modifies the session' do
        expect_any_instance_of(DocAuth::Mock::DocAuthMockClient).
          to receive(:post_images).with(
            front_image: an_instance_of(String),
            back_image: an_instance_of(String),
            selfie_image: nil,
            image_source: :unknown,
            user_uuid: an_instance_of(String),
            uuid_prefix: nil,
            liveness_checking_required: false,
            images_cropped: false,
          ).and_call_original

        action

        expect(response.status).to eq(200)
        expect(json[:success]).to eq(true)
        expect(document_capture_session.reload.load_result.success?).to eq(true)
      end

      it 'tracks events' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          error_details: nil,
          user_id: user.uuid,
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          flow_path: 'standard',
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          liveness_checking_required: boolean,
        )

        expect(@analytics).to have_logged_event(
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
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          flow_path: 'standard',
          vendor_request_time_in_ms: a_kind_of(Float),
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          doc_type_supported: boolean,
          doc_auth_success: boolean,
          selfie_status: :not_processed,
          liveness_checking_required: boolean,
          selfie_live: boolean,
          selfie_quality_good: boolean,
          address_line2_present: nil,
          alert_failure_count: nil,
          conversation_id: nil,
          request_id: nil,
          decision_product_status: nil,
          image_metrics: nil,
          log_alert_results: nil,
          portrait_match_results: nil,
          processed_alerts: nil,
          product_status: nil,
          reference: nil,
          transaction_reason_code: nil,
          transaction_status: nil,
          vendor: nil,
          workflow: an_instance_of(String),
          birth_year: 1938,
          zip_code: '59010',
        )

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload vendor pii validation',
          success: true,
          errors: {},
          error_details: nil,
          attention_with_barcode: false,
          user_id: user.uuid,
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          flow_path: 'standard',
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          liveness_checking_required: boolean,
          classification_info: a_kind_of(Hash),
          id_issued_status: 'present',
          id_expiration_status: 'present',
        )

        expect_funnel_update_counts(user, 1)
      end

      context 'but doc_pii validation fails' do
        let(:first_name) { 'FAKEY' }
        let(:last_name) { 'MCFAKERSON' }
        let(:address1) { '123 Houston Ave' }
        let(:state) { 'ND' }
        let(:state_id_type) { 'drivers_license' }
        let(:dob) { '10/06/1938' }
        let(:jurisdiction) { 'ND' }
        let(:zipcode) { '12345' }
        let(:country_code) { 'USA' }
        let(:class_name) { 'Identification Card' }

        before do
          DocAuth::Mock::DocAuthMockClient.mock_response!(
            method: :get_results,
            response: DocAuth::Response.new(
              success: true,
              errors: {},
              extra: {
                doc_auth_result: 'Passed',
                billed: true,
                classification_info: {
                  Front: {
                    CountryCode: country_code,
                    ClassName: class_name,
                  },
                  Back: {
                    CountryCode: country_code,
                    ClassName: class_name,
                  },
                },
              },
              pii_from_doc: Pii::StateId.new(
                first_name: first_name,
                last_name: last_name,
                middle_name: nil,
                address1: address1,
                state: state,
                state_id_type: state_id_type,
                dob: dob,
                state_id_jurisdiction: jurisdiction,
                state_id_number: state_id_number,
                zipcode: zipcode,
                address2: nil,
                city: nil,
                state_id_expiration: nil,
                state_id_issued: nil,
                issuing_country_code: nil,
              ),
            ),
          )
        end

        context 'due to invalid Name' do
          let(:first_name) { nil }

          it 'tracks name validation errors in analytics' do
            stub_analytics

            action

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              error_details: nil,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
            )

            expect(@analytics).to have_logged_event(
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
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              flow_path: 'standard',
              vendor_request_time_in_ms: a_kind_of(Float),
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              doc_type_supported: boolean,
              doc_auth_success: boolean,
              selfie_status: :not_processed,
              liveness_checking_required: boolean,
              selfie_live: true,
              selfie_quality_good: true,
              address_line2_present: nil,
              alert_failure_count: nil,
              conversation_id: nil,
              request_id: nil,
              decision_product_status: nil,
              image_metrics: nil,
              log_alert_results: nil,
              portrait_match_results: nil,
              processed_alerts: nil,
              product_status: nil,
              reference: nil,
              transaction_reason_code: nil,
              transaction_status: nil,
              vendor: nil,
              birth_year: 1938,
              zip_code: '12345',
            )

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                name: [I18n.t('doc_auth.errors.alerts.full_name_check')],
              },
              error_details: {
                name: { name: true },
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
              classification_info: hash_including(
                Front: hash_including(ClassName: 'Identification Card', CountryCode: 'USA'),
                Back: hash_including(ClassName: 'Identification Card', CountryCode: 'USA'),
              ),
              id_issued_status: 'missing',
              id_expiration_status: 'missing',
            )
          end
        end

        context 'due to invalid State' do
          let(:state) { 'Maryland' }

          it 'tracks state validation errors in analytics' do
            stub_analytics

            action

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              error_details: nil,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
            )

            expect(@analytics).to have_logged_event(
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
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              flow_path: 'standard',
              vendor_request_time_in_ms: a_kind_of(Float),
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              doc_type_supported: boolean,
              doc_auth_success: boolean,
              selfie_status: :not_processed,
              liveness_checking_required: boolean,
              selfie_live: true,
              selfie_quality_good: true,
              address_line2_present: nil,
              alert_failure_count: nil,
              conversation_id: nil,
              request_id: nil,
              decision_product_status: nil,
              image_metrics: nil,
              log_alert_results: nil,
              portrait_match_results: nil,
              processed_alerts: nil,
              product_status: nil,
              reference: nil,
              transaction_reason_code: nil,
              transaction_status: nil,
              vendor: nil,
              birth_year: 1938,
              zip_code: '12345',
            )

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                state: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              error_details: {
                state: { inclusion: true },
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
              classification_info: hash_including(
                Front: hash_including(ClassName: 'Identification Card', CountryCode: 'USA'),
                Back: hash_including(ClassName: 'Identification Card', CountryCode: 'USA'),
              ),
              id_issued_status: 'missing',
              id_expiration_status: 'missing',
            )
          end
        end

        context 'but doc_pii validation fails due to missing state_id_number' do
          let(:state_id_number) { nil }

          it 'tracks state_id_number validation errors in analytics' do
            stub_analytics

            action

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              error_details: nil,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
            )

            expect(@analytics).to have_logged_event(
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
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              flow_path: 'standard',
              vendor_request_time_in_ms: a_kind_of(Float),
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              doc_type_supported: boolean,
              doc_auth_success: boolean,
              selfie_status: :not_processed,
              liveness_checking_required: boolean,
              selfie_live: true,
              selfie_quality_good: true,
              address_line2_present: nil,
              alert_failure_count: nil,
              conversation_id: nil,
              request_id: nil,
              decision_product_status: nil,
              image_metrics: nil,
              log_alert_results: nil,
              portrait_match_results: nil,
              processed_alerts: nil,
              product_status: nil,
              reference: nil,
              transaction_reason_code: nil,
              transaction_status: nil,
              vendor: nil,
              birth_year: 1938,
              zip_code: '12345',
            )

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                state_id_number: [I18n.t('doc_auth.errors.general.no_liveness')],
              },
              error_details: {
                state_id_number: { blank: true },
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
              classification_info: hash_including(:Front, :Back),
              id_issued_status: 'missing',
              id_expiration_status: 'missing',
            )
          end
        end

        context 'but doc_pii validation fails due to invalid DOB' do
          let(:dob) { nil }

          it 'tracks dob validation errors in analytics' do
            stub_analytics

            action

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload form submitted',
              success: true,
              errors: {},
              error_details: nil,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
            )

            expect(@analytics).to have_logged_event(
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
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              client_image_metrics: {
                front: { glare: 99.99 },
                back: { glare: 99.99 },
              },
              flow_path: 'standard',
              vendor_request_time_in_ms: a_kind_of(Float),
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              doc_type_supported: boolean,
              doc_auth_success: boolean,
              selfie_status: :not_processed,
              liveness_checking_required: boolean,
              selfie_live: true,
              selfie_quality_good: true,
              address_line2_present: nil,
              alert_failure_count: nil,
              conversation_id: nil,
              request_id: nil,
              decision_product_status: nil,
              image_metrics: nil,
              log_alert_results: nil,
              portrait_match_results: nil,
              processed_alerts: nil,
              product_status: nil,
              reference: nil,
              transaction_reason_code: nil,
              transaction_status: nil,
              vendor: nil,
              birth_year: nil,
              zip_code: '12345',
            )

            expect(@analytics).to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
              success: false,
              errors: {
                dob: [I18n.t('doc_auth.errors.alerts.birth_date_checks')],
              },
              error_details: {
                dob: { dob: true },
              },
              attention_with_barcode: false,
              user_id: user.uuid,
              submit_attempts: 1,
              remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
              flow_path: 'standard',
              front_image_fingerprint: an_instance_of(String),
              back_image_fingerprint: an_instance_of(String),
              selfie_image_fingerprint: nil,
              liveness_checking_required: boolean,
              classification_info: hash_including(:Front, :Back),
              id_issued_status: 'missing',
              id_expiration_status: 'missing',
            )
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
        expect(json[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
        expect(json[:errors]).to eq [
          {
            field: 'front',
            message: I18n.t('doc_auth.errors.general.multiple_front_id_failures'),
          },
        ]
      end

      it 'tracks events' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          error_details: nil,
          user_id: user.uuid,
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          flow_path: 'standard',
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          liveness_checking_required: boolean,
        )

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          success: false,
          errors: {
            front: [I18n.t('doc_auth.errors.general.multiple_front_id_failures')],
          },
          attention_with_barcode: false,
          user_id: user.uuid,
          submit_attempts: 1,
          billed: nil,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          state: nil,
          state_id_type: nil,
          exception: nil,
          async: false,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          doc_auth_result: nil,
          flow_path: 'standard',
          vendor_request_time_in_ms: a_kind_of(Float),
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          doc_type_supported: boolean,
          doc_auth_success: boolean,
          selfie_status: :not_processed,
          liveness_checking_required: boolean,
          selfie_live: true,
          selfie_quality_good: true,
          address_line2_present: nil,
          alert_failure_count: nil,
          conversation_id: nil,
          request_id: nil,
          decision_product_status: nil,
          image_metrics: nil,
          log_alert_results: nil,
          portrait_match_results: nil,
          processed_alerts: nil,
          product_status: nil,
          reference: nil,
          transaction_reason_code: nil,
          transaction_status: nil,
          vendor: nil,
          birth_year: nil,
          zip_code: nil,
        )

        expect_funnel_update_counts(user, 1)
      end
    end

    context 'when a value is an error-formatted yaml file' do
      before { params.merge!(back: DocAuthImageFixtures.error_yaml_multipart) }

      it 'returns error from yaml file' do
        action

        expect(json[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
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

        action

        expect(@analytics).to have_logged_event(
          'IdV: doc auth image upload form submitted',
          success: true,
          errors: {},
          error_details: nil,
          user_id: user.uuid,
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          flow_path: 'standard',
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          liveness_checking_required: boolean,
        )

        expect(@analytics).to have_logged_event(
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
          submit_attempts: 1,
          remaining_submit_attempts: IdentityConfig.store.doc_auth_max_attempts - 1,
          client_image_metrics: {
            front: { glare: 99.99 },
            back: { glare: 99.99 },
          },
          flow_path: 'standard',
          vendor_request_time_in_ms: a_kind_of(Float),
          front_image_fingerprint: an_instance_of(String),
          back_image_fingerprint: an_instance_of(String),
          selfie_image_fingerprint: nil,
          doc_type_supported: boolean,
          doc_auth_success: boolean,
          selfie_status: :not_processed,
          liveness_checking_required: boolean,
          selfie_live: boolean,
          selfie_quality_good: boolean,
          address_line2_present: nil,
          alert_failure_count: nil,
          conversation_id: nil,
          request_id: nil,
          decision_product_status: nil,
          image_metrics: nil,
          log_alert_results: nil,
          portrait_match_results: nil,
          processed_alerts: nil,
          product_status: nil,
          reference: nil,
          transaction_reason_code: nil,
          transaction_status: nil,
          vendor: nil,
          workflow: an_instance_of(String),
          birth_year: nil,
          zip_code: nil,
        )

        expect_funnel_update_counts(user, 1)
      end
    end

    context 'when required pii field is missing from doc response' do
      before { params.merge!(back: DocAuthImageFixtures.error_yaml_no_db_multipart) }

      it 'returns error' do
        action

        expect(response.status).to eq(400)
        expect(json[:success]).to eq(false)
        expect(json[:remaining_submit_attempts]).to be_a_kind_of(Numeric)
        expect(json[:errors]).to eq [
          {
            field: 'dob',
            message: I18n.t('doc_auth.errors.alerts.birth_date_checks'),
          },
          {
            field: 'front',
            message: I18n.t('doc_auth.errors.general.multiple_front_id_failures'),
          },
          {
            field: 'back',
            message: I18n.t('doc_auth.errors.general.multiple_back_id_failures'),
          },
        ]
      end
    end

    context 'the frontend requests a selfie' do
      before do
        authn_context_result = Vot::Parser.new(vector_of_trust: 'Pb').parse
        allow(controller).to(
          receive(:resolved_authn_context_result).and_return(authn_context_result),
        )
      end

      let(:back_image) { DocAuthImageFixtures.portrait_match_success_yaml }
      let(:selfie_img) { DocAuthImageFixtures.selfie_image_multipart }

      it 'returns a successful response' do
        action
        expect(response.status).to eq(200)
        expect(json[:success]).to eq(true)
        expect(document_capture_session.reload.load_result.success?).to eq(true)
        expect(document_capture_session.reload.load_result.selfie_check_performed?).to eq(true)
      end

      it 'sends a selfie' do
        expect_any_instance_of(DocAuth::Mock::DocAuthMockClient).
          to receive(:post_images).with(
            front_image: an_instance_of(String),
            back_image: an_instance_of(String),
            selfie_image: an_instance_of(String),
            image_source: :unknown,
            user_uuid: an_instance_of(String),
            uuid_prefix: nil,
            liveness_checking_required: true,
            images_cropped: false,
          ).and_call_original

        action
        expect(response.status).to eq(200)
        expect(json[:success]).to eq(true)
        expect(document_capture_session.reload.load_result.success?).to eq(true)
      end
    end
  end

  def expect_funnel_update_counts(user, count)
    doc_auth_log = DocAuthLog.where(user_id: user.id).first
    expect(doc_auth_log.back_image_submit_count).to eq(count)
    expect(doc_auth_log.front_image_submit_count).to eq(count)
  end
end
