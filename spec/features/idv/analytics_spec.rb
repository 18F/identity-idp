require 'rails_helper'

feature 'Analytics Regression', js: true do
  include IdvStepHelper
  include InPersonHelper

  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  # rubocop:disable Layout/LineLength
  let(:happy_path_events) do
    common_events = {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => { flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth welcome submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth agreement visited' => { flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth agreement submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth upload visited' => { flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth upload submitted' => { success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', step_count: 1 },
      'Frontend: IdV: front image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard' },
      'Frontend: IdV: document capture async upload encryption' => { 'success' => true, 'flow_path' => 'standard' }, # { 'success' => true, 'flow_path' => 'standard' },
      'Frontend: IdV: back image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard' },
      'Frontend: IdV: document capture async upload submitted' => { 'success' => true, 'trace_id' => nil, 'status_code' => 200, 'flow_path' => 'standard' },
      'IdV: doc auth image upload form submitted' => { success: true, errors: {}, attempts: nil, remaining_attempts: 3, user_id: nil, flow_path: 'standard' },
      'IdV: doc auth image upload vendor pii validation' => { success: true, errors: {}, user_id: nil, remaining_attempts: 3, flow_path: 'standard' },
      'IdV: doc auth verify_document_status submitted' => { success: true, errors: {}, remaining_attempts: 3, flow_path: 'standard', step: 'verify_document_status', step_count: 1 },
      'IdV: doc auth document_capture submitted' => { success: false, errors: { front_image: ['Please fill in this field.'], back_image: ['Please fill in this field.'] }, is_fallback_link: false, error_details: { front_image: [:blank], back_image: [:blank] }, flow_path: 'standard', step: 'document_capture', step_count: 1 },
      'IdV: doc auth ssn visited' => { flow_path: 'standard', step: 'ssn', step_count: 1 },
      'IdV: doc auth ssn submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'ssn', step_count: 1 },
      'IdV: doc auth verify visited' => { flow_path: 'standard', step: 'verify', step_count: 1 },
      'IdV: doc auth verify submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'verify', step_count: 1 },
      'IdV: doc auth verify_wait visited' => { flow_path: 'standard', step: 'verify_wait', step_count: 1 },
      'IdV: doc auth optional verify_wait submitted' => { success: true, errors: {}, address_edited: false, proofing_results: { exception: nil, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', timed_out: false, context: { should_proof_state_id: true, stages: { resolution: { client: 'ResolutionMock', errors: {}, exception: nil, success: true, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc' }, state_id: { client: 'StateIdMock', errors: {}, success: true, timed_out: false, exception: nil, transaction_id: 'state-id-mock-transaction-id-456', state: 'MT', state_id_jurisdiction: 'ND' } } } }, ssn_is_unique: true, step: 'verify_wait_step_show' },
      'IdV: phone of record visited' => {},
      'IdV: phone confirmation form' => { success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202' },
      'IdV: phone confirmation vendor' => { success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false }, new_phone_added: false },
      'IdV: final resolution' => { success: true },
      'IdV: personal key visited' => {},
      'IdV: personal key submitted' => {},
    }
    {
      FSMv1: common_events.merge(
        'Frontend: IdV: show personal key modal' => {},
      ),
      FSMv2: common_events.merge(
        'IdV: personal key confirm visited' => {},
        'IdV: personal key confirm submitted' => {},
      ),
    }
  end
  let(:gpo_path_events) do
    common_events = {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => { flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth welcome submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth agreement visited' => { flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth agreement submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth upload visited' => { flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth upload submitted' => { success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', step_count: 1 },
      'Frontend: IdV: front image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard' },
      'Frontend: IdV: document capture async upload encryption' => { 'success' => true, 'flow_path' => 'standard' }, # { 'success' => true, 'flow_path' => 'standard' },
      'Frontend: IdV: back image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard' },
      'Frontend: IdV: document capture async upload submitted' => { 'success' => true, 'trace_id' => nil, 'status_code' => 200, 'flow_path' => 'standard' },
      'IdV: doc auth image upload form submitted' => { success: true, errors: {}, attempts: nil, remaining_attempts: 3, user_id: nil, flow_path: 'standard' },
      'IdV: doc auth image upload vendor pii validation' => { success: true, errors: {}, user_id: nil, remaining_attempts: 3, flow_path: 'standard' },
      'IdV: doc auth verify_document_status submitted' => { success: true, errors: {}, remaining_attempts: 3, flow_path: 'standard', step: 'verify_document_status', step_count: 1 },
      'IdV: doc auth document_capture submitted' => { success: false, errors: { front_image: ['Please fill in this field.'], back_image: ['Please fill in this field.'] }, is_fallback_link: false, error_details: { front_image: [:blank], back_image: [:blank] }, flow_path: 'standard', step: 'document_capture', step_count: 1 },
      'IdV: doc auth ssn visited' => { flow_path: 'standard', step: 'ssn', step_count: 1 },
      'IdV: doc auth ssn submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'ssn', step_count: 1 },
      'IdV: doc auth verify visited' => { flow_path: 'standard', step: 'verify', step_count: 1 },
      'IdV: doc auth verify submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'verify', step_count: 1 },
      'IdV: doc auth verify_wait visited' => { flow_path: 'standard', step: 'verify_wait', step_count: 1 },
      'IdV: doc auth optional verify_wait submitted' => { success: true, errors: {}, address_edited: false, proofing_results: { exception: nil, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', timed_out: false, context: { should_proof_state_id: true, stages: { resolution: { client: 'ResolutionMock', errors: {}, exception: nil, success: true, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc' }, state_id: { client: 'StateIdMock', errors: {}, success: true, timed_out: false, exception: nil, transaction_id: 'state-id-mock-transaction-id-456', state: 'MT', state_id_jurisdiction: 'ND' } } } }, ssn_is_unique: true, step: 'verify_wait_step_show' },
      'IdV: phone of record visited' => {},
      'IdV: USPS address letter requested' => { enqueued_at: Time.zone.now },
    }
    {
      FSMv1: common_events,
      FSMv2: common_events,
    }
  end
  let(:in_person_path_events) do
    {
      'IdV: doc auth welcome visited' => { flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth welcome submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth agreement visited' => { flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth agreement submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth upload visited' => { flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth upload submitted' => { success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', step_count: 1 },
      'Frontend: IdV: front image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard' },
      'Frontend: IdV: document capture async upload encryption' => { 'success' => true, 'flow_path' => 'standard' },
      'Frontend: IdV: back image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard' },
      'Frontend: IdV: document capture async upload submitted' => { 'success' => true, 'trace_id' => nil, 'status_code' => 200, 'flow_path' => 'standard' },
      'IdV: doc auth image upload form submitted' => { success: true, errors: {}, attempts: nil, remaining_attempts: 3, user_id: nil, flow_path: 'standard' },
      'IdV: doc auth image upload vendor submitted' => { success: true, flow_path: 'standard', attention_with_barcode: true, doc_auth_result: 'Attention' },
      'IdV: doc auth verify_document_status submitted' => { success: true, flow_path: 'standard', step: 'verify_document_status', attention_with_barcode: true, doc_auth_result: 'Attention' },
      'IdV: verify in person troubleshooting option clicked' => {},
      'IdV: in person proofing location visited' => { 'flow_path' => 'standard' },
      'IdV: in person proofing location submitted' => { 'flow_path' => 'standard', 'selected_location' => 'BALTIMORE' },
      'IdV: in person proofing prepare visited' => { 'flow_path' => 'standard' },
      'IdV: in person proofing prepare submitted' => { 'flow_path' => 'standard' },
      'IdV: in person proofing state_id visited' => { step: 'state_id', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing state_id submitted' => { success: true, flow_path: 'standard', step: 'state_id', step_count: 1 },
      'IdV: in person proofing address visited' => { step: 'address', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing address submitted' => { success: true, step: 'address', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing ssn visited' => { step: 'ssn', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing ssn submitted' => { success: true, step: 'ssn', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing verify visited' => { step: 'verify', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing verify submitted' => { success: true, step: 'verify', flow_path: 'standard', step_count: 1 },
      'IdV: in person proofing verify_wait visited' => { flow_path: 'standard', step: 'verify_wait', step_count: 1 },
      'IdV: in person proofing optional verify_wait submitted' => { success: true, step: 'verify_wait_step_show', address_edited: false, ssn_is_unique: true },
      'IdV: phone of record visited' => {},
      'IdV: phone confirmation form' => { success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202' },
      'IdV: phone confirmation vendor' => { success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false }, new_phone_added: false },
      'IdV: Phone OTP delivery Selection Visited' => {},
      'IdV: Phone OTP Delivery Selection Submitted' => { success: true, otp_delivery_preference: 'sms' },
      'IdV: phone confirmation otp sent' => { success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202' },
      'IdV: phone confirmation otp visited' => {},
      'IdV: phone confirmation otp submitted' => { success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil },
      'IdV: review info visited' => {},
      'IdV: review complete' => { success: true },
      'IdV: final resolution' => { success: true },
      'IdV: personal key visited' => {},
      'Frontend: IdV: show personal key modal' => {},
      'IdV: personal key submitted' => {},
      'IdV: in person ready to verify visited' => {},
    }
  end
  # rubocop:enable Layout/LineLength

  # Needed for enqueued_at in gpo_step
  around do |ex|
    freeze_time { ex.run }
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(DocumentProofingJob).to receive(:build_analytics).
      and_return(fake_analytics)
  end

  {
    FSMv1: [],
    FSMv2: %w[password_confirm personal_key personal_key_confirm],
  }.each do |flow_version, steps_enabled|
    context flow_version do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(steps_enabled)
        WebMock.allow_net_connect!(net_http_connect_on_start: true)
      end

      after do
        webmock_allow_list = WebMock::Config.instance.allow
        WebMock.disallow_net_connect!(net_http_connect_on_start: nil, allow: webmock_allow_list)
      end

      context 'Happy path' do
        before do
          sign_in_and_2fa_user(user)
          visit_idp_from_sp_with_ial2(:oidc)
          complete_welcome_step
          complete_agreement_step
          complete_upload_step
          complete_document_capture_step
          complete_ssn_step
          complete_verify_step
          complete_phone_step(user)
          complete_review_step(user)
          acknowledge_and_confirm_personal_key
        end

        it 'records all of the events' do
          happy_path_events[flow_version].each do |event, _attributes|
            expect(fake_analytics).to have_logged_event(event)
          end
        end
      end

      context 'GPO path' do
        before do
          sign_in_and_2fa_user(user)
          visit_idp_from_sp_with_ial2(:oidc)
          complete_welcome_step
          complete_agreement_step
          complete_upload_step
          complete_document_capture_step
          complete_ssn_step
          complete_verify_step
          enter_gpo_flow
          gpo_step
        end

        it 'records all of the events' do
          gpo_path_events[flow_version].each do |event, _attributes|
            expect(fake_analytics).to have_logged_event(event)
          end
        end
      end
    end
  end

  context 'in person path' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)

      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_all_in_person_proofing_steps(user)
      complete_phone_step(user)
      complete_review_step(user)
      acknowledge_and_confirm_personal_key
    end

    it 'records all of the events', allow_browser_log: true do
      in_person_path_events.each do |event, attributes|
        expect(fake_analytics).to have_logged_event(event, attributes)
      end
    end
  end
end
