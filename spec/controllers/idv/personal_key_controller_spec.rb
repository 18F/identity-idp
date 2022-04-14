require 'rails_helper'

describe Idv::PersonalKeyController do
  include SamlAuthHelper
  include PersonalKeyValidator

  def stub_idv_session
    stub_sign_in(user)
    idv_session = Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      service_provider: nil,
    )
    idv_session.applicant = applicant
    idv_session.resolution_successful = true
    profile_maker = Idv::ProfileMaker.new(
      applicant: applicant,
      user: user,
      user_password: password,
    )
    profile = profile_maker.save_profile
    idv_session.pii = profile_maker.pii_attributes
    idv_session.profile_id = profile.id
    idv_session.personal_key = profile.personal_key
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end

  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :signed_up, password: password) }
  let(:applicant) do
    {
      first_name: 'Some',
      last_name: 'One',
      address1: '123 Any St',
      address2: 'Ste 456',
      city: 'Anywhere',
      state: 'KS',
      zipcode: '66666',
    }
  end
  let(:profile) { subject.idv_session.profile }

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_vendor_session_started,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end

    describe '#confirm_profile_has_been_created' do
      before do
        stub_idv_session
      end

      controller do
        before_action :confirm_profile_has_been_created

        def index
          render plain: 'Hello'
        end
      end

      context 'profile has been created' do
        it 'does not redirect' do
          get :index

          expect(response).to_not be_redirect
        end
      end

      context 'profile has not been created' do
        before do
          subject.idv_session.profile_id = nil
        end

        it 'redirects to the account path' do
          get :index

          expect(response).to redirect_to account_path
        end
      end
    end
  end

  describe '#show' do
    before do
      stub_idv_session
    end

    it 'sets code instance variable' do
      subject.idv_session.create_profile_from_applicant_with_password(password)
      code = subject.idv_session.personal_key

      get :show

      expect(assigns(:code)).to eq(code)
    end

    it 'can decrypt the profile with the code' do
      get :show

      code = assigns(:code)

      expect(PersonalKeyGenerator.new(user).verify(code)).to eq true
      expect(user.profiles.first.recover_pii(normalize_personal_key(code))).to eq(
        subject.idv_session.pii,
      )
    end

    it 'sets flash[:allow_confirmations_continue] to true' do
      get :show

      expect(flash[:allow_confirmations_continue]).to eq true
    end

    it 'sets flash.now[:success]' do
      get :show
      expect(flash[:success]).to eq t('idv.messages.confirm')
    end

    context 'user selected gpo verification' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
      end

      it 'assigns step indicator steps with pending status' do
        get :show

        expect(flash.now[:success]).to eq t('idv.messages.mail_sent')
        expect(assigns(:step_indicator_steps)).to include(
          hash_including(name: :verify_phone_or_address, status: :pending),
        )
      end
    end
  end

  describe '#update' do
    before do
      stub_idv_session
    end

    context 'user selected phone verification' do
      before do
        subject.idv_session.address_verification_mechanism = 'phone'
        subject.idv_session.vendor_phone_confirmation = true
        subject.idv_session.user_phone_confirmation = true
        subject.idv_session.complete_session
      end

      it 'redirects to sign up completed for an sp' do
        subject.session[:sp] = { ial2: true }
        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end

      it 'redirects to the account path when no sp present' do
        patch :update

        expect(response).to redirect_to account_path
      end

      it 'clears need_personal_key_confirmation session state' do
        subject.user_session[:need_personal_key_confirmation] = true
        patch :update

        expect(subject.user_session[:need_personal_key_confirmation]).to eq(false)
      end
    end

    context 'user selected gpo verification' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
        subject.idv_session.complete_session
      end

      it 'redirects to come back later path' do
        patch :update

        expect(response).to redirect_to idv_come_back_later_path
      end
    end
  end
end
