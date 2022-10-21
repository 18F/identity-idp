require 'rails_helper'

describe Idv::DocAuthController do
  include DocAuthHelper

  let(:user) { build(:user) }

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :initialize_flow_state_machine,
        :ensure_correct_step,
        :override_csp_for_threat_metrix,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  let(:user) { build(:user) }

  before do |example|
    stub_sign_in(user) if user
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', domain: 'example.com'))
  end

  describe 'unauthenticated' do
    let(:user) { nil }

    it 'redirects to the root url' do
      get :index

      expect(response).to redirect_to root_url
    end
  end

  describe '#index' do
    it 'redirects to the first step' do
      get :index

      expect(response).to redirect_to idv_doc_auth_step_url(step: :welcome)
    end

    context 'with pending in person enrollment' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'redirects to in person ready to verify page' do
        get :index

        expect(response).to redirect_to idv_in_person_ready_to_verify_url
      end
    end
  end

  describe '#show' do
    it 'renders the correct template' do
      expect(subject).to receive(:render).with(
        template: 'layouts/flow_step',
        locals: hash_including(
          :back_image_upload_url,
          :front_image_upload_url,
          :selfie_image_upload_url,
          :flow_session,
          step_template: 'idv/doc_auth/document_capture',
          flow_namespace: 'idv',
        ),
      ).and_call_original

      mock_next_step(:document_capture)
      get :show, params: { step: 'document_capture' }
    end

    it 'redirects to the right step' do
      mock_next_step(:document_capture)
      get :show, params: { step: 'ssn' }

      expect(response).to redirect_to idv_doc_auth_step_url(:document_capture)
    end

    it 'renders a 404 with a non existent step' do
      get :show, params: { step: 'foo' }

      expect(response).to_not be_not_found
    end

    it 'tracks analytics' do
      result = { step: 'welcome', flow_path: 'standard', step_count: 1 }

      get :show, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth welcome visited', result
      )
    end

    it 'tracks analytics for the optional step' do
      mock_next_step(:verify_wait)
      result = { errors: {}, step: 'verify_wait_step_show', success: true }

      get :show, params: { step: 'verify_wait' }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth optional verify_wait submitted', result
      )
    end

    it 'increments the analytics step counts on subsequent submissions' do
      get :show, params: { step: 'welcome' }
      get :show, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).ordered.with(
        'IdV: doc auth welcome visited',
        hash_including(step: 'welcome', step_count: 1),
      )
      expect(@analytics).to have_received(:track_event).ordered.with(
        'IdV: doc auth welcome visited',
        hash_including(step: 'welcome', step_count: 2),
      )
    end

    context 'with an existing applicant' do
      before do
        idv_session = Idv::Session.new(
          user_session: controller.user_session,
          current_user: user,
          service_provider: nil,
        )
        idv_session.applicant = {}
        allow(controller).to receive(:idv_session).and_return(idv_session)
      end

      it 'finishes the flow' do
        get :show, params: { step: 'welcome' }

        expect(response).to redirect_to idv_review_url
      end
    end
  end

  describe '#update' do
    it 'tracks analytics' do
      mock_next_step(:back_image)
      allow_any_instance_of(Flow::BaseFlow).to \
        receive(:flow_session).and_return(pii_from_doc: {})
      result = {
        success: true,
        errors: {},
        step: 'ssn',
        flow_path: 'standard',
        step_count: 1,
        pii_like_keypaths: [[:errors, :ssn], [:error_details, :ssn]],
      }

      put :update, params: { step: 'ssn', doc_auth: { step: 'ssn', ssn: '111-11-1111' } }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth ssn submitted', result
      )
    end

    it 'increments the analytics step counts on subsequent submissions' do
      mock_next_step(:back_image)
      allow_any_instance_of(Flow::BaseFlow).to \
        receive(:flow_session).and_return(pii_from_doc: {})

      put :update, params: { step: 'ssn', doc_auth: { step: 'ssn', ssn: '666-66-6666' } }
      put :update, params: { step: 'ssn', doc_auth: { step: 'ssn', ssn: '111-11-1111' } }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth ssn submitted',
        hash_including(step: 'ssn', step_count: 1),
      )
      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth ssn submitted',
        hash_including(step: 'ssn', step_count: 2),
      )
    end

    it 'redirects from welcome to no camera error' do
      result = {
        success: false,
        errors: {
          message: 'Doc Auth error: Javascript could not detect camera on mobile device.',
        },
        step: 'welcome',
        flow_path: 'standard',
        step_count: 1,
      }

      put :update, params: {
        step: 'welcome',
        ial2_consent_given: true,
        no_camera: true,
      }

      expect(response).to redirect_to idv_doc_auth_errors_no_camera_url
      expect(@analytics).to have_received(:track_event).with(
        'IdV: doc auth welcome submitted', result
      )
    end

    context 'with an existing applicant' do
      before do
        idv_session = Idv::Session.new(
          user_session: controller.user_session,
          current_user: user,
          service_provider: nil,
        )
        idv_session.applicant = {}
        allow(controller).to receive(:idv_session).and_return(idv_session)
      end

      it 'finishes the flow' do
        put :update, params: { step: 'ssn' }

        expect(response).to redirect_to idv_review_url
      end
    end
  end

  describe 'async document verify status' do
    before do
      mock_document_capture_step
    end
    let(:good_pii) do
      {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        dob: (Time.zone.today - (IdentityConfig.store.idv_min_age_years + 1).years).to_s,
        address1: Faker::Address.street_address,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zipcode: Faker::Address.zip_code,
        state_id_type: 'drivers_license',
        state_id_number: '111',
        state_id_jurisdiction: 'WI',
      }
    end
    let(:good_result) do
      {
        success: true,
        errors: {},
        messages: ['message'],
        pii_from_doc: good_pii,
        attention_with_barcode: false,
      }
    end
    let(:bad_pii) do
      {
        first_name: Faker::Name.first_name,
        last_name: nil,
        dob: nil,
        address1: Faker::Address.street_address,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zipcode: Faker::Address.zip_code,
        state_id_type: 'drivers_license',
        state_id_number: '111',
        state_id_jurisdiction: 'WI',
      }
    end
    let(:bad_pii_result) do
      {
        success: true,
        errors: {},
        messages: ['message'],
        pii_from_doc: bad_pii,
        attention_with_barcode: false,
      }
    end
    let(:fail_result) do
      {
        pii_from_doc: {},
        success: false,
        errors: { front: 'Wrong document' },
        messages: ['message'],
        attention_with_barcode: false,
      }
    end
    let(:hard_fail_result) do
      {
        pii_from_doc: {},
        success: false,
        errors: { front: 'Wrong document' },
        messages: ['message'],
        attention_with_barcode: false,
        doc_auth_result: 'Failed',
      }
    end

    it 'returns status of success' do
      set_up_document_capture_result(
        uuid: document_capture_session_uuid,
        idv_result: good_result,
      )
      put :update,
          params: {
            step: 'verify_document_status',
            document_capture_session_uuid: document_capture_session_uuid,
          }

      expect(response.status).to eq(200)
      expect(response.body).to eq({ success: true }.to_json)
    end

    it 'returns status of in progress' do
      set_up_document_capture_result(
        uuid: document_capture_session_uuid,
        idv_result: nil,
      )
      put :update,
          params: {
            step: 'verify_document_status',
            document_capture_session_uuid: document_capture_session_uuid,
          }

      expect(response.status).to eq(202)
      expect(response.body).to eq({ success: true }.to_json)
    end

    it 'returns status of fail' do
      set_up_document_capture_result(
        uuid: document_capture_session_uuid,
        idv_result: fail_result,
      )
      put :update,
          params: {
            step: 'verify_document_status',
            document_capture_session_uuid: document_capture_session_uuid,
          }

      expect(response.status).to eq(400)
      expect(response.body).to eq(
        {
          success: false,
          errors: [{ field: 'front', message: 'Wrong document' }],
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
          ocr_pii: nil,
          result_failed: false,
        }.to_json,
      )
    end

    it 'returns status of hard fail' do
      set_up_document_capture_result(
        uuid: document_capture_session_uuid,
        idv_result: hard_fail_result,
      )
      put :update,
          params: {
            step: 'verify_document_status',
            document_capture_session_uuid: document_capture_session_uuid,
          }

      expect(response.status).to eq(400)
      expect(response.body).to eq(
        {
          success: false,
          errors: [{ field: 'front', message: 'Wrong document' }],
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
          ocr_pii: nil,
          result_failed: true,
        }.to_json,
      )
    end

    it 'returns status of fail with incomplete PII from doc auth' do
      set_up_document_capture_result(
        uuid: document_capture_session_uuid,
        idv_result: bad_pii_result,
      )

      expect(@analytics).to receive(:track_event).with(
        'IdV: doc auth image upload vendor pii validation', include(
          errors: include(
            pii: [I18n.t('doc_auth.errors.general.no_liveness')],
          ),
          error_details: { pii: [I18n.t('doc_auth.errors.general.no_liveness')] },
          attention_with_barcode: false,
          success: false,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
          flow_path: 'standard',
          pii_like_keypaths: [[:pii]],
          user_id: nil,
        )
      )

      expect(@analytics).to receive(:track_event).with(
        'IdV: doc auth verify_document_status submitted', include(
          errors: include(
            pii: [I18n.t('doc_auth.errors.general.no_liveness')],
          ),
          error_details: { pii: [I18n.t('doc_auth.errors.general.no_liveness')] },
          attention_with_barcode: false,
          success: false,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
          step: 'verify_document_status',
          flow_path: 'standard',
          step_count: 1,
          pii_like_keypaths: [[:pii]],
          doc_auth_result: nil,
        )
      )

      put :update,
          params: {
            step: 'verify_document_status',
            document_capture_session_uuid: document_capture_session_uuid,
          }

      expect(response.status).to eq(400)
      expect(response.body).to eq(
        {
          success: false,
          errors: [{ field: 'pii',
                     message: I18n.t('doc_auth.errors.general.no_liveness') }],
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
          ocr_pii: nil,
          result_failed: false,
        }.to_json,
      )
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::DocAuthFlow).to receive(:next_step).and_return(step)
  end

  let(:user) { create(:user, :signed_up) }
  let(:document_capture_session_uuid) { DocumentCaptureSession.create!(user: user).uuid }

  def mock_document_capture_step
    stub_sign_in(user)
    allow_any_instance_of(Flow::BaseFlow).to \
      receive(:flow_session).and_return(
        'document_capture_session_uuid' => document_capture_session_uuid,
        'Idv::Steps::WelcomeStep' => true,
        'Idv::Steps::SendLinkStep' => true,
        'Idv::Steps::LinkSentStep' => true,
        'Idv::Steps::EmailSentStep' => true,
        'Idv::Steps::UploadStep' => true,
      )
  end
end
