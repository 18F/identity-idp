require 'rails_helper'
require 'proofer/vendor/mock'

describe Verify::ConfirmationsController do
  include IdvHelper
  include SamlAuthHelper

  let(:password) { 'sekrit phrase' }
  let(:user) { build_stubbed(:user, :signed_up, password: password) }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:profile) do
    user.unlock_user_access_key(password)
    Idv::ProfileFromApplicant.create(applicant, user)
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_vendor_session_started
      )
    end
  end

  context 'session started' do
    before do
      stub_idv_session
    end

    context 'original SAML Authn request present' do
      let(:saml_authn_request) { sp1_authnrequest }

      before do
        subject.session[:saml_request_url] = saml_authn_request
        get :index
      end

      it 'redirects to original SAML Authn request' do
        post :continue

        expect(response).to redirect_to saml_authn_request
      end
    end

    context 'original SAML Authn request missing' do
      before do
        subject.session[:saml_request_url] = nil
      end

      it 'cleans up PII from session' do
        get :index

        expect(subject.idv_session.alive?).to eq false
      end

      it 'activates profile' do
        get :index
        profile.reload

        expect(profile).to be_active
        expect(profile.verified_at).to_not be_nil
      end

      it 'resets IdV attempts' do
        attempter = instance_double(Idv::Attempter, reset: false)
        allow(Idv::Attempter).to receive(:new).with(user).and_return(attempter)

        expect(attempter).to receive(:reset)

        get :index
      end

      it 'sets recovery code instance variable' do
        subject.idv_session.cache_applicant_profile_id(applicant)
        code = subject.idv_session.recovery_code
        get :index

        expect(assigns(:recovery_code)).to eq(code)
      end

      it 'redirects to IdP profile after user acknowledges recovery code' do
        post :continue

        expect(response).to redirect_to(profile_path)
      end

      it 'sets flash[:allow_confirmations_continue] to true' do
        get :index

        expect(flash[:allow_confirmations_continue]).to eq true
      end

      it 'tracks final IdV event' do
        stub_analytics

        result = {
          success: true,
          new_phone_added: false
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::IDV_FINAL, result)

        get :index
      end
    end

    context 'user confirmed a new phone' do
      it 'tracks that event' do
        stub_analytics
        subject.idv_session.params['phone_confirmed_at'] = Time.current

        result = {
          success: true,
          new_phone_added: true
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::IDV_FINAL, result)

        get :index
      end
    end
  end

  context 'IdV session not yet started' do
    it 'redirects to /idv/sessions' do
      stub_sign_in(user)

      get :index

      expect(response).to redirect_to(verify_session_path)
    end
  end
end
