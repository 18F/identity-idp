require 'rails_helper'
require 'proofer/vendor/mock'

describe Verify::ConfirmationsController do
  include SamlAuthHelper

  def stub_idv_session
    stub_sign_in(user)
    idv_session = Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      issuer: nil
    )
    idv_session.vendor = :mock
    idv_session.applicant = idv_session.vendor_params
    idv_session.normalized_applicant_params = { first_name: 'Somebody' }
    idv_session.resolution_successful = resolution.success?
    user.unlock_user_access_key(password)
    profile_maker = Idv::ProfileMaker.new(
      applicant: applicant,
      user: user,
      normalized_applicant: normalized_applicant,
      vendor: :mock,
      phone_confirmed: true
    )
    profile = profile_maker.profile
    idv_session.pii = profile_maker.pii_attributes
    idv_session.profile_id = profile.id
    idv_session.personal_key = profile.personal_key
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(context: 'idv')
  end

  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :signed_up, password: password) }
  let(:applicant) do
    Proofer::Applicant.new(
      first_name: 'Some',
      last_name: 'One',
      address1: '123 Any St',
      address2: 'Ste 456',
      city: 'Anywhere',
      state: 'KS',
      zipcode: '66666'
    )
  end
  let(:normalized_applicant) { Proofer::Applicant.new first_name: 'Somebody' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:profile) { subject.idv_session.profile }

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
      before do
        subject.idv_session.params['phone'] = user.phone
        subject.idv_session.params['phone_confirmed_at'] = Time.zone.now
        subject.idv_session.vendor_phone_confirmation = true
        subject.idv_session.user_phone_confirmation = true
      end

      it 'activates profile' do
        get :show
        profile.reload

        expect(profile).to be_active
        expect(profile.verified_at).to_not be_nil
      end

      it 'sets code instance variable' do
        subject.idv_session.cache_applicant_profile_id
        code = subject.idv_session.personal_key

        get :show

        expect(assigns(:code)).to eq(code)
      end

      it 'sets flash[:allow_confirmations_continue] to true' do
        get :show

        expect(flash[:allow_confirmations_continue]).to eq true
      end

      it 'sets flash.now[:success]' do
        get :show
        expect(flash[:success]).to eq t('idv.messages.confirm')
      end

      it 'tracks final IdV event' do
        stub_analytics

        result = {
          success: true,
          new_phone_added: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::IDV_FINAL, result)

        get :show
      end

      it 'creates an `account_verified` event once per confirmation' do
        event_creator = instance_double(CreateVerifiedAccountEvent)
        expect(CreateVerifiedAccountEvent).to receive(:new).and_return(event_creator)
        expect(event_creator).to receive(:call)

        get :show
      end
    end

    context 'user picked USPS confirmation' do
      before do
        subject.idv_session.address_verification_mechanism = 'usps'
      end

      it 'leaves profile deactivated' do
        expect(UspsConfirmation.count).to eq 0

        get :show
        profile.reload

        expect(profile).to_not be_active
        expect(profile.verified_at).to be_nil
        expect(profile.deactivation_reason).to eq 'verification_pending'
        expect(UspsConfirmation.count).to eq 1
      end

      it 'redirects to account page' do
        subject.session[:sp] = { loa3: true }
        patch :update

        expect(response).to redirect_to account_url
      end
    end

    context 'user confirmed a new phone' do
      it 'tracks that event' do
        stub_analytics
        subject.idv_session.params['phone'] = '+1 (202) 555-9876'
        subject.idv_session.params['phone_confirmed_at'] = Time.zone.now

        result = {
          success: true,
          new_phone_added: true,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::IDV_FINAL, result)

        get :show
      end
    end
  end

  context 'IdV session not yet started' do
    it 'redirects to /idv/sessions' do
      stub_sign_in(user)

      get :show

      expect(response).to redirect_to(verify_session_path)
    end
  end

  describe '#update' do
    context 'sp present' do
      it 'redirects to the sign up completed url' do
        stub_idv_session
        subject.session[:sp] = 'true'
        stub_sign_in

        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end
    end

    context 'no sp present' do
      it 'redirects to the account page' do
        stub_idv_session
        stub_sign_in

        patch :update

        expect(response).to redirect_to account_path
      end
    end
  end
end
