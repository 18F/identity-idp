require 'rails_helper'

feature 'Analytics Regression' do
  include IdvStepHelper

  let(:fake_analytics) { FakeAnalytics.new }
  # rubocop:disable Layout/LineLength
  let(:happy_path_events) do
    {
      'OpenID Connect: authorization request' => { acr_values: 'http://idmanagement.gov/ns/assurance/ial/2', client_id: 'urn:gov:gsa:openidconnect:sp:server', errors: {}, scope: 'email openid phone profile:name social_security_number', success: true, unauthorized_scope: false, user_fully_authenticated: false },
      'Sign in page visited' => { flash: nil, stored_location: nil },
      'Account Page Visited' => {},
      'IdV: doc auth welcome visited' => { flow_path: 'standard', step: 'welcome', step_count: 1 },
      'IdV: doc auth welcome submitted' => { errors: {}, flow_path: 'standard', step: 'welcome', step_count: 1, success: true },
      'IdV: doc auth agreement visited' => { flow_path: 'standard', step: 'agreement', step_count: 1 },
      'IdV: doc auth agreement submitted' => { errors: {}, flow_path: 'standard', step: 'agreement', step_count: 1, success: true },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', step_count: 1 },
      'IdV: doc auth document_capture submitted' => { billed: true, doc_auth_result: 'Passed', errors: {}, flow_path: 'standard', is_fallback_link: true, step: 'document_capture', step_count: 1, success: true },
      'IdV: doc auth optional verify_wait submitted' => { address_edited: false, errors: {}, proofing_results: { context: { dob_year_only: false, should_proof_state_id: true, stages: { resolution: { client: 'ResolutionMock', errors: {}, exception: nil, reference: 'aaa-bbb-ccc', success: true, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123' }, state_id: { client: 'StateIdMock', errors: {}, exception: nil, state: 'MT', state_id_jurisdiction: 'ND', success: true, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456' } } }, exception: nil, messages: [], reference: 'aaa-bbb-ccc', timed_out: false, transaction_id: 'resolution-mock-transaction-id-123' }, ssn_is_unique: true, step: 'verify_wait_step_show', success: true },
      'IdV: doc auth ssn visited' => { flow_path: 'standard', step: 'ssn', step_count: 1 },
      'IdV: doc auth ssn submitted' => { errors: {}, flow_path: 'standard', step: 'ssn', step_count: 1, success: true },
      'IdV: doc auth upload visited' => { flow_path: 'standard', step: 'upload', step_count: 1 },
      'IdV: doc auth upload submitted' => { destination: :document_capture, errors: {}, flow_path: 'standard', step: 'upload', step_count: 1, success: true },
      'IdV: doc auth verify submitted' => { errors: {}, flow_path: 'standard', step: 'verify', step_count: 1, success: true },
      'IdV: doc auth verify visited' => { flow_path: 'standard', step: 'verify', step_count: 1 },
      'IdV: doc auth verify_wait visited' => { flow_path: 'standard', step: 'verify_wait', step_count: 1 },
      'IdV: phone of record visited' => {},
      'IdV: phone confirmation form' => { area_code: '202', carrier: 'Test Mobile Carrier', country_code: 'US', errors: {}, phone_type: :mobile, success: true, types: [:fixed_or_mobile] },
      'IdV: phone confirmation vendor' => { errors: {}, new_phone_added: false, success: true, vendor: { context: { stages: [{ address: 'AddressMock' }] }, exception: nil, messages: [], timed_out: false, transaction_id: 'address-mock-transaction-id-123' } },
      'IdV: final resolution' => { success: true },
      'IdV: personal key visited' => {},
      'IdV: review complete' => {},
      'IdV: review info visited' => {},
    }
  end
  # rubocop:enable Layout/LineLength

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
  end

  {
    FSMv1: [],
    # FSMv2: %w[personal_key, personal_key_confirm],
  }.each do |flow_version, steps_enabled|
    context flow_version do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(steps_enabled)
      end

      context 'Happy path' do
        before do
          visit_idp_from_sp_with_ial2(:oidc)
          complete_idv_steps_with_phone_before_confirmation_step
        end

        it 'records all of the events' do
          happy_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end
      end
    end
  end
end
