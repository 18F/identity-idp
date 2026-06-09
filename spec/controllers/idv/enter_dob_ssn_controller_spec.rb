require 'rails_helper'

RSpec.describe Idv::EnterDobSsnController do
  let(:idv_proofing_agent_enabled) { true }
  let(:success) { true }
  let(:pii) do
    {
      ssn: '123456789',
      dob: '1990-01-01',
    }
  end
  let(:agent_proofed_user) do
    {
      pii: pii,
      success: success,
      proofing_agent_id: 'agent_123',
      proofing_location_id: 'location_456',
      correlation_id: 'correlation_789',
      transaction_id: document_capture_session.uuid,
      service_provider_issuer: sp.issuer,
    }
  end
  let(:sp) { create(:service_provider, :idv, :active) }
  let(:user) { create(:user, :fully_registered) }
  let(:document_capture_session) do
    DocumentCaptureSession.create!(
      user: user,
      doc_auth_vendor: Idp::Constants::Vendors::PROOFING_AGENT,
      issuer: sp.issuer,
    )
  end
  let(:idv_session) { subject.idv_session }
  let(:resolved_authn_context_result) do
    Component::Parser.new(acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR).parse
  end
  let(:proofing_agent_device_profiling) { :disabled }
  let(:tmx_session_id) { nil }

  before do
    stub_sign_in(user)
    stub_analytics
    document_capture_session.store_agent_proofed_user(agent_proofed_user)
    resolver_mock = instance_double(AuthnContextResolver)
    allow(resolver_mock).to receive(:result).and_return(resolved_authn_context_result)
    allow(AuthnContextResolver).to receive(:new).and_return(resolver_mock)
    allow(IdentityConfig.store).to receive_messages(
      {
        idv_proofing_agent_enabled:,
        proofing_agent_device_profiling:,
        lexisnexis_threatmetrix_org_id: 'org1',
      },
    )
    allow(controller.idv_session).to receive(:threatmetrix_session_id).and_return(tmx_session_id)
  end

  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_verification_needed,
        :move_agent_proofed_user_pii_to_idv_session,
        :override_csp_for_threat_metrix,
      )
    end

    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#new' do
    let(:response) { get :new }

    context 'proofing agent feature is disabled' do
      let(:idv_proofing_agent_enabled) { false }

      it 'redirects to the account page' do
        expect(response).to redirect_to(account_url)
      end
    end

    context 'user does not have a proofing agent pending pii' do
      let(:success) { false }

      it 'redirects to account url if user does not have a pending proofing agent' do
        expect(response).to redirect_to(account_url)
      end
    end

    context 'user has proofing agent pending pii' do
      before { get :new }

      it 'moves agent proofed user pii to idv_session applicant' do
        expect(subject.idv_session.applicant).to eq(pii.stringify_keys)
      end

      it 'sets session[:sp] as a hash with the issuer' do
        expect(session[:sp].with_indifferent_access[:issuer]).to eq(sp.issuer)
      end

      it 'sets current_sp to the service provider from the agent proofed session' do
        expect(controller.current_sp).to eq(sp)
      end

      it 'sets phone step to completed' do
        expect(subject.idv_session.address_verification_mechanism).to eq('phone')
        expect(subject.idv_session.vendor_phone_confirmation).to eq true
        expect(subject.idv_session.user_phone_confirmation).to eq true
      end

      it 'sends the correct analytics' do
        expect(@analytics).to have_logged_event(
          :idv_proofing_agent_user_confirmation_visited,
          issuer: sp.issuer,
          proofing_agent: a_kind_of(Hash),
        )
      end
    end

    context 'with threatmetrix disabled' do
      let(:proofing_agent_device_profiling) { :disabled }

      it 'does not override CSPs for ThreatMetrix' do
        expect(controller).not_to receive(:override_csp_for_threat_metrix)

        response
      end
    end

    context 'with threatmetrix enabled' do
      let(:proofing_agent_device_profiling) { :enabled }
      let(:tmx_session_id) { '1234' }

      before do
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled)
          .and_return(false)
      end

      it 'renders new valid request' do
        tmx_url = 'https://h.online-metrix.net/fp'
        expect(controller).to receive(:render).with(
          :new,
          locals: hash_including(
            threatmetrix_session_id: tmx_session_id,
            threatmetrix_javascript_urls:
              ["#{tmx_url}/tags.js?org_id=org1&session_id=#{tmx_session_id}"],
            threatmetrix_iframe_url:
              "#{tmx_url}/tags?org_id=org1&session_id=#{tmx_session_id}",
          ),
        ).and_call_original

        response
      end

      it 'overrides CSPs for ThreatMetrix' do
        expect(controller).to receive(:override_csp_for_threat_metrix)

        response
      end
    end
  end

  describe '#create' do
    let(:ssn) { pii[:ssn] }
    let(:year) { '1990' }
    let(:dob) {  { year:, month: '01', day: '01' } }
    let(:params) do
      {
        doc_auth: {
          ssn:,
          dob:,
        },
      }
    end

    context 'user typed dob and ssn matches idv_session.applicant dob and ssn' do
      it 'redirects to enter password step' do
        post :create, params: params

        expect(response).to redirect_to(idv_enter_password_url)
        expect(@analytics).to have_logged_event(
          :idv_proofing_agent_user_confirmation_submitted,
          success: true,
          dob_match: true,
          ssn_match: true,
          dob_and_ssn_match: true,
          issuer: sp.issuer,
          proofing_agent: a_kind_of(Hash),
        )
      end
    end

    context 'user typed ssn does not match idv_session.applicant ssn' do
      let(:ssn) { '000000000' }

      it 'renders new' do
        post :create, params: params

        expect(response).to render_template(:new)
      end
    end

    context 'user typed dob does not match idv_session.applicant dob' do
      let(:year) { '2000' }

      it 'renders new' do
        post :create, params: params

        expect(response).to render_template(:new)
      end
    end

    context 'when proofing agent threatmetrix is not enabled' do
      it 'does not save a threatmetrix result' do
        expect { put :create, params: params }.not_to change { DeviceProfilingResult.count }
      end
    end

    context 'when proofing agent threatmetrix is enabled' do
      let(:tmx_session_id) { 'test-tmx-session-id-1234' }
      let(:proofing_agent_device_profiling) { :enabled }

      it 'saves the threatmetrix result to db' do
        expect { put :create, params: params }.to change { DeviceProfilingResult.count }

        result = DeviceProfilingResult.last
        expect(result.review_status).to eq('pass')
        expect(result.transaction_id).to eq('ddp-mock-transaction-id-123')
      end
    end
  end
end
