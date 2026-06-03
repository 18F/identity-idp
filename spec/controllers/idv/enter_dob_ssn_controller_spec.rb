require 'rails_helper'

RSpec.describe Idv::EnterDobSsnController do
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
    }
  end
  let(:sp) { create(:service_provider, :idv, :active) }
  let(:user) { create(:user, :fully_registered) }
  let(:document_capture_session) do
    DocumentCaptureSession.create!(user: user, issuer: sp.issuer)
  end
  let(:idv_session) { subject.idv_session }
  let(:resolved_authn_context_result) do
    Component::Parser.new(acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR).parse
  end

  before do
    stub_sign_in(user)
    document_capture_session.store_agent_proofed_user(agent_proofed_user)
    resolver_mock = instance_double(AuthnContextResolver)
    allow(resolver_mock).to receive(:result).and_return(resolved_authn_context_result)
    allow(AuthnContextResolver).to receive(:new).and_return(resolver_mock)
  end

  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_verification_needed,
        :move_agent_proofed_user_pii_to_idv_session,
      )
    end

    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#new' do
    before { get :new }
    context 'user does not have a proofing agent pending pii' do
      let(:success) { false }

      it 'redirects to account_url if user does not have a pending proofing agent' do
        expect(response).to redirect_to(account_url)
      end
    end

    context 'user has proofing agent pending pii' do
      it 'moves agent proofed user pii to idv_session applicant' do
        expect(subject.idv_session.applicant).to eq(pii.stringify_keys)
      end

      it 'sets session[:sp] as a hash with the issuer' do
        expect(session[:sp].with_indifferent_access[:issuer]).to eq(sp.issuer)
      end

      it 'sets current_sp to the service provider from the agent proofed session' do
        expect(controller.current_sp).to eq(sp)
      end
    end
  end

  describe '#create' do
    before { get :new }

    context 'user typed dob and ssn matches idv_session.applicant dob and ssn' do
      it 'redirects to enter password step' do
        post :create, params: {
          doc_auth: {
            ssn: pii[:ssn],
            dob: { year: '1990', month: '01', day: '01' },
          },
        }
        expect(response).to redirect_to(idv_enter_password_url)
      end
    end

    context 'user typed ssn does not match idv_session.applicant ssn' do
      it 'renders new' do
        post :create, params: {
          doc_auth: {
            ssn: '000000000',
            dob: { year: '1990', month: '01', day: '01' },
          },
        }
        expect(response).to render_template(:new)
      end
    end

    context 'user typed dob does not match idv_session.applicant dob' do
      it 'renders new' do
        post :create, params: {
          doc_auth: {
            ssn: pii[:ssn],
            dob: { year: '2000', month: '06', day: '15' },
          },
        }
        expect(response).to render_template(:new)
      end
    end
  end
end
