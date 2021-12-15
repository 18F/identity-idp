require 'rails_helper'

describe Idv::DocAuthController do
  include DocAuthHelper

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :fsm_initialize,
        :ensure_correct_step,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  before do |example|
    stub_sign_in unless example.metadata[:skip_sign_in]
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', domain: 'example.com'))
  end

  describe 'unauthenticated', :skip_sign_in do
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
          step_indicator: hash_including(
            :steps,
            current_step: :verify_id,
          ),
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
        'IdV: ' + "#{Analytics::DOC_AUTH} welcome visited".downcase, result
      )
    end

    it 'tracks analytics for the optional step' do
      mock_next_step(:verify_wait)
      result = { errors: {}, step: 'verify_wait_step_show', success: true }

      get :show, params: { step: 'verify_wait' }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: ' + "#{Analytics::DOC_AUTH} optional verify_wait submitted".downcase, result
      )
    end

    it 'increments the analytics step counts on subsequent submissions' do
      get :show, params: { step: 'welcome' }
      get :show, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).ordered.with(
        'IdV: ' + "#{Analytics::DOC_AUTH} welcome visited".downcase,
        hash_including(step: 'welcome', step_count: 1),
      )
      expect(@analytics).to have_received(:track_event).ordered.with(
        'IdV: ' + "#{Analytics::DOC_AUTH} welcome visited".downcase,
        hash_including(step: 'welcome', step_count: 2),
      )
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

      put :update, params: {step: 'ssn', doc_auth: { step: 'ssn', ssn: '111-11-1111' } }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: ' + "#{Analytics::DOC_AUTH} ssn submitted".downcase, result
      )
    end

    it 'increments the analytics step counts on subsequent submissions' do
      mock_next_step(:back_image)
      allow_any_instance_of(Flow::BaseFlow).to \
        receive(:flow_session).and_return(pii_from_doc: {})
      result = {
        success: true,
        errors: {},
        step: 'ssn',
        step_count: 1,
        pii_like_keypaths: [[:errors, :ssn], [:error_details, :ssn]],
      }

      put :update, params: {step: 'ssn', doc_auth: { step: 'ssn', ssn: '666-66-6666' } }
      put :update, params: {step: 'ssn', doc_auth: { step: 'ssn', ssn: '111-11-1111' } }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: ' + "#{Analytics::DOC_AUTH} ssn submitted".downcase,
        hash_including(step: 'ssn', step_count: 1),
      )
      expect(@analytics).to have_received(:track_event).with(
        'IdV: ' + "#{Analytics::DOC_AUTH} ssn submitted".downcase,
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
        'IdV: ' + "#{Analytics::DOC_AUTH} welcome submitted".downcase, result
      )
    end
  end

  describe 'async document verify' do
    let(:front_image_url) { 'http://foo.com/bar1' }
    let(:back_image_url) { 'http://foo.com/bar2' }
    let(:selfie_image_url) { 'http://foo.com/bar3' }
    let(:encryption_key) { SecureRandom.random_bytes(32) }
    let(:front_image_iv) { SecureRandom.random_bytes(12) }
    let(:back_image_iv) { SecureRandom.random_bytes(12) }
    let(:selfie_image_iv) { SecureRandom.random_bytes(12) }
    encryption_helper = JobHelpers::EncryptionHelper.new

    before do
      mock_document_capture_step

      encryption_helper = JobHelpers::EncryptionHelper.new
      stub_request(:get, front_image_url).
        to_return(body: encryption_helper.encrypt(
          data: '{}', key: encryption_key, iv: front_image_iv,
        ))
      stub_request(:get, back_image_url).
        to_return(body: encryption_helper.encrypt(
          data: '{}', key: encryption_key, iv: back_image_iv,
        ))
      stub_request(:get, selfie_image_url).
        to_return(body: encryption_helper.encrypt(
          data: '{}', key: encryption_key, iv: selfie_image_iv,
        ))
    end
    let(:successful_response) do
      { success: true }.to_json
    end

    context 'with selfie checking disabled' do
      it 'successfully submits the images' do
        put :update, params: { step: 'verify_document',
                               document_capture_session_uuid: 'foo',
                               encryption_key: Base64.encode64(encryption_key),
                               front_image_iv: Base64.encode64(front_image_iv),
                               back_image_iv: Base64.encode64(back_image_iv),
                               selfie_image_iv: Base64.encode64(selfie_image_iv),
                               front_image_url: front_image_url,
                               back_image_url: back_image_url,
                               selfie_image_url: selfie_image_url }

        expect(response.status).to eq(202)
        expect(response.body).to eq(successful_response)
      end

      it 'fails to submit the images' do
        put :update, params: { step: 'verify_document' }

        expect(response.status).to eq(400)
      end
    end

    context 'with selfie checking enabled' do
      before do
        allow(IdentityConfig.store).to receive(:liveness_checking_enabled).and_return(true)
      end

      it 'successfully submits the images' do
        put :update, params: { step: 'verify_document',
                               document_capture_session_uuid: 'foo',
                               encryption_key: Base64.encode64(encryption_key),
                               front_image_iv: Base64.encode64(front_image_iv),
                               back_image_iv: Base64.encode64(back_image_iv),
                               selfie_image_iv: Base64.encode64(selfie_image_iv),
                               front_image_url: front_image_url,
                               back_image_url: back_image_url,
                               selfie_image_url: selfie_image_url }

        expect(response.status).to eq(202)
        expect(response.body).to eq(successful_response)
      end

      it 'fails to submit the images' do
        put :update, params: { step: 'verify_document' }

        expect(response.status).to eq(400)
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
      }
    end
    let(:fail_result) do
      {
        pii_from_doc: {},
        success: false,
        errors: { front: 'Wrong document' },
        messages: ['message'],
      }
    end

    it 'returns status of success' do
      set_up_document_capture_result(
        uuid: verify_document_action_session_uuid,
        idv_result: good_result,
      )
      put :update, params: { step: 'verify_document_status' }

      expect(response.status).to eq(200)
      expect(response.body).to eq({ success: true }.to_json)
    end

    it 'returns status of in progress' do
      set_up_document_capture_result(
        uuid: verify_document_action_session_uuid,
        idv_result: nil,
      )
      put :update, params: { step: 'verify_document_status' }

      expect(response.status).to eq(202)
      expect(response.body).to eq({ success: true }.to_json)
    end

    it 'returns status of fail' do
      set_up_document_capture_result(
        uuid: verify_document_action_session_uuid,
        idv_result: fail_result,
      )
      put :update, params: { step: 'verify_document_status' }

      expect(response.status).to eq(400)
      expect(response.body).to eq(
        {
          success: false,
          errors: [{ field: 'front', message: 'Wrong document' }],
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
        }.to_json,
      )
    end

    it 'returns status of fail with incomplete PII from doc auth' do
      set_up_document_capture_result(
        uuid: verify_document_action_session_uuid,
        idv_result: bad_pii_result,
      )
      put :update, params: { step: 'verify_document_status' }

      expect(response.status).to eq(400)
      expect(response.body).to eq(
        {
          success: false,
          errors: [{ field: 'pii',
                     message: I18n.t('doc_auth.errors.general.no_liveness') }],
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
        }.to_json,
      )
      expect(@analytics).to have_received(:track_event).with(
        'IdV: ' + "#{Analytics::DOC_AUTH} verify_document_status submitted".downcase, {
          errors: { pii: [I18n.t('doc_auth.errors.general.no_liveness')] },
          error_details: { pii: [I18n.t('doc_auth.errors.general.no_liveness')] },
          success: false,
          remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
          step: 'verify_document_status',
          flow_path: 'standard',
          step_count: 1,
          pii_like_keypaths: [[:pii]],
        }
      )
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::DocAuthFlow).to receive(:next_step).and_return(step)
  end

  let(:user) { create(:user, :signed_up) }
  let(:verify_document_action_session_uuid) { DocumentCaptureSession.create!(user: user).uuid }

  def mock_document_capture_step
    stub_sign_in(user)
    DocumentCaptureSession.create(user_id: user.id, result_id: 1, uuid: 'foo')
    allow_any_instance_of(Flow::BaseFlow).to \
      receive(:flow_session).and_return(
        'document_capture_session_uuid' => 'foo',
        'Idv::Steps::WelcomeStep' => true,
        'Idv::Steps::SendLinkStep' => true,
        'Idv::Steps::LinkSentStep' => true,
        'Idv::Steps::EmailSentStep' => true,
        'Idv::Steps::UploadStep' => true,
        verify_document_action_document_capture_session_uuid: verify_document_action_session_uuid,
      )
  end
end
