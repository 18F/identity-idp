require 'rails_helper'

describe Idv::ReviewController do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
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
  let(:idv_session) { Idv::Session.new(subject.user_session, user) }

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
        get 'show' => 'idv/review#show'
      end
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    context 'user has missed phone step' do
      before do
        idv_session.params = user_attrs.reject { |key| key == :phone }
      end

      it 'redirects to phone step' do
        get :show

        expect(response).to redirect_to idv_phone_path
      end
    end

    context 'user has missed finance step' do
      before do
        idv_session.params = user_attrs.reject { |key| key == :ccn }
      end

      it 'redirects to finance step' do
        get :show

        expect(response).to redirect_to idv_finance_path
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

    context 'user has completed all steps' do
      before do
        idv_session.params = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      end

      it 'redirects to questions path' do
        put :create

        expect(response).to redirect_to idv_questions_path
      end
    end

    context 'user attributes fail to resolve' do
      before do
        idv_session.params = user_attrs.merge(first_name: 'Bad')
      end

      it 'redirects to retry' do
        put :create

        expect(response).to redirect_to idv_retry_url
      end

      context 'max attempts exceeded' do
        before do
          user.idv_attempts = 3
        end

        it 'redirects to fail' do
          put :create

          expect(response).to redirect_to idv_fail_url
        end
      end
    end

    context 'user has entered different phone number from MFA' do
      before do
        idv_session.params = user_attrs.merge(phone: '213-555-1000')
      end

      it 'redirects to phone confirmation path' do
        put :create

        expect(response).to render_template('devise/two_factor_authentication/show')
      end
    end
  end
end
