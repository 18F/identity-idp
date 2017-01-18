require 'rails_helper'

describe Verify::ReviewController do
  let(:user) do
    create(
      :user,
      :signed_up,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'old_email@example.com'
    )
  end
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666661234',
      dob: 'March 29, 1972',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044',
      phone: user.phone,
      ccn: '12345678'
    }
  end
  let(:idv_session) do
    idv_session = Idv::Session.new(subject.user_session, user)
    happy_args = { success: true, session_id: 'some-id' }
    idv_session.resolution = Proofer::Resolution.new happy_args
    idv_session.phone_confirmation = Proofer::Confirmation.new happy_args
    idv_session.financials_confirmation = true
    idv_session
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_idv_steps_complete,
        :confirm_idv_attempts_allowed
      )
    end
  end

  describe '#confirm_idv_steps_complete' do
    controller do
      before_action :confirm_idv_steps_complete

      def show
        render text: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'verify/review#show'
      end
      idv_session.params = user_attrs
      allow(subject).to receive(:idv_session).and_return(idv_session)
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    end

    context 'user has missed phone step' do
      before do
        idv_session.phone_confirmation.success = false
      end

      it 'redirects to phone step' do
        get :show

        expect(response).to redirect_to verify_phone_path
      end
    end

    context 'user has missed finance step' do
      before do
        idv_session.financials_confirmation = false
      end

      it 'redirects to finance step' do
        get :show

        expect(response).to redirect_to verify_finance_path
      end
    end
  end

  describe '#confirm_current_password' do
    controller do
      before_action :confirm_current_password

      def show
        render text: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        post 'show' => 'verify/review#show'
      end
      allow(subject).to receive(:confirm_idv_steps_complete).and_return(true)
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
      idv_session.params = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    context 'user does not provide password' do
      it 'redirects to new' do
        post :show, user: { password: '' }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to verify_review_path
      end
    end

    context 'user provides wrong password' do
      it 'redirects to new' do
        post :show, user: { password: 'wrong' }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to verify_review_path
      end
    end

    context 'user provides correct password' do
      it 'allows request to proceed' do
        post :show, user: { password: ControllerHelper::VALID_PASSWORD }

        expect(response.body).to eq 'Hello'
      end
    end
  end

  describe '#new' do
    before do
      stub_sign_in(user)
      allow(subject).to receive(:confirm_idv_session_started).and_return(true)
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    end

    context 'user has completed all steps' do
      before do
        idv_session.params = user_attrs
      end

      it 'shows completed session' do
        get :new

        expect(response).to render_template :new
      end
    end
  end

  describe '#create' do
    before do
      stub_sign_in(user)
      allow(subject).to receive(:confirm_idv_session_started).and_return(true)
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    end

    context 'user fails to supply correct password' do
      before do
        idv_session.params = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      end

      it 'redirects to original path' do
        put :create, user: { password: 'wrong' }

        expect(response).to redirect_to verify_review_path
      end
    end

    context 'user has completed all steps' do
      before do
        idv_session.params = user_attrs
        idv_session.applicant = idv_session.applicant_from_params
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'redirects to confirmation path' do
        put :create, user: { password: ControllerHelper::VALID_PASSWORD }

        expect(@analytics).to have_received(:track_event).with(Analytics::IDV_REVIEW_COMPLETE)
        expect(response).to redirect_to verify_confirmations_path
      end
    end

    context 'user has entered different phone number from MFA' do
      before do
        idv_session.params = user_attrs.merge(phone: '213-555-1000')
        idv_session.applicant = idv_session.applicant_from_params
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'redirects to phone confirmation path' do
        put :create, user: { password: ControllerHelper::VALID_PASSWORD }

        expect(@analytics).to have_received(:track_event).with(Analytics::IDV_REVIEW_COMPLETE)
        expect(response).to render_template('users/two_factor_authentication/show')
        expect(subject.user_session[:context]).to eq 'idv'
      end
    end
  end
end
