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
    idv_session.applicant = idv_session.vendor_params
    idv_session.normalized_applicant_params = { first_name: 'Somebody' }
    idv_session.resolution_successful = true
    user.unlock_user_access_key(password)
    profile_maker = Idv::ProfileMaker.new(
      applicant: applicant,
      user: user,
      normalized_applicant: normalized_applicant,
      phone_confirmed: true
    )
    profile = profile_maker.save_profile
    idv_session.pii = profile_maker.pii_attributes
    idv_session.profile_id = profile.id
    idv_session.personal_key = profile.personal_key
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(context: 'idv')
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
      zipcode: '66666'
    }
  end
  let(:normalized_applicant) { { first_name: 'Somebody' } }
  let(:profile) { subject.idv_session.profile }

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_vendor_session_started
      )
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

    context 'user used 2FA phone as phone of record' do
      before do
        subject.idv_session.params['phone'] = user.phone
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
    end

    context 'user confirmed a new phone' do
      before do
        subject.idv_session.params['phone'] = '+1 (202) 555-9876'
      end

      it 'tracks final IdV event' do
        stub_analytics

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
        subject.session[:sp] = { loa3: true }
        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end

      it 'redirects to the account path when no sp present' do
        patch :update

        expect(response).to redirect_to account_path
      end
    end

    context 'user selected usps verification' do
      before do
        subject.idv_session.address_verification_mechanism = 'usps'
        subject.idv_session.complete_session
      end

      it 'redirects to come back later path' do
        patch :update

        expect(response).to redirect_to verify_come_back_later_path
      end
    end
  end
end
