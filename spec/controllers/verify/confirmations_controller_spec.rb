require 'rails_helper'
require 'proofer/vendor/mock'

describe Verify::ConfirmationsController do
  include SamlAuthHelper

  def stub_idv_session
    stub_sign_in(user)
    idv_session = Idv::Session.new(subject.user_session, user)
    idv_session.vendor = :mock
    idv_session.applicant = applicant
    idv_session.resolution = resolution
    idv_session.profile_id = profile.id
    idv_session.recovery_code = profile.recovery_code
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end

  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :signed_up, password: password) }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:normalized_applicant) { Proofer::Applicant.new first_name: 'Somebody' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:profile) do
    user.unlock_user_access_key(password)
    Idv::ProfileFromApplicant.create(
      applicant: applicant,
      user: user,
      normalized_applicant: normalized_applicant
    )
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

    context 'user used 2FA phone as phone of record' do
      it 'activates profile' do
        get :index
        profile.reload

        expect(profile).to be_active
        expect(profile.verified_at).to_not be_nil
      end

      it 'sets recovery code instance variable' do
        subject.idv_session.cache_applicant_profile_id
        code = subject.idv_session.recovery_code
        get :index

        expect(assigns(:recovery_code)).to eq(code)
      end

      it 'sets flash[:allow_confirmations_continue] to true' do
        get :index

        expect(flash[:allow_confirmations_continue]).to eq true
      end

      it 'tracks final IdV event' do
        stub_analytics

        result = {
          success: true,
          new_phone_added: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::IDV_FINAL, result)

        get :index
      end
    end

    context 'user confirmed a new phone' do
      it 'tracks that event' do
        stub_analytics
        subject.idv_session.params['phone_confirmed_at'] = Time.zone.now

        result = {
          success: true,
          new_phone_added: true,
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
