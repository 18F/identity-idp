require 'rails_helper'

RSpec.describe AccountsController do
  describe 'before_actions' do
    it 'includes before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
      expect(subject).to have_actions(
        :before,
        :confirm_user_is_not_suspended,
      )
    end
  end

  describe '#show' do
    context 'signed out' do
      it 'redirects to sign in' do
        get :show

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    describe 'pii fetching' do
      let(:pii_cacher) { Pii::Cacher.new(user, {}) }
      let(:active_profile) { create(:profile, :active) }
      let(:pending_profile) { create(:profile, :verify_by_mail_pending) }
      let(:user) { create(:user, :fully_registered, profiles: profiles) }

      before do
        allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)
        allow(pii_cacher).to receive(:fetch).and_call_original

        sign_in user
        get :show
      end

      context 'when the user has no profiles' do
        let(:profiles) { [] }

        it 'uses no PII' do
          expect(pii_cacher).to have_received(:fetch).with(nil)
        end
      end

      context 'when the user has an active profile and a pending profile' do
        let(:profiles) { [active_profile, pending_profile] }

        it 'uses PII from the active profile' do
          expect(pii_cacher).to have_received(:fetch).with(active_profile.id)
        end
      end

      context 'when the user has no active profile but has a pending profile' do
        let(:profiles) { [pending_profile] }

        it 'uses PII from the pending profile' do
          expect(pii_cacher).to have_received(:fetch).with(pending_profile.id)
        end
      end
    end

    context 'when user has an active identity' do
      it 'renders the profile and does not redirect out of the app' do
        stub_analytics
        user = create(:user, :fully_registered)
        user.identities << ServiceProviderIdentity.create(
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.zone.now,
        )

        sign_in user

        get :show

        expect(@analytics).to have_logged_event('Account Page Visited')
        expect(response).to_not be_redirect
      end
    end

    context 'when user just added new email through select email flow' do
      context 'when user is in select email form flow' do
        before do
          session[:from_select_email_flow] = true
        end
        it 'renders the proper flash message' do
          flash_message = t(
            'account.emails.confirmed_html',
            url: account_connected_accounts_url,
          )
          user = create(:user, :fully_registered)
          sign_in user

          get :show

          expect(response).to_not be_redirect
          expect(flash[:success]).to eq(flash_message)
          expect(session[:from_select_email_flow]).to be_nil
        end
      end

      context 'when user is not in email form flow' do
        before do
          session[:from_select_email_flow] = false
        end
        it 'renders proper flash message' do
          t('devise.confirmations.confirmed')
          user = create(:user, :fully_registered)
          sign_in user

          get :show
          expect(flash[:success]).to be_nil
        end
      end
    end

    context 'when a profile has been deactivated by password reset' do
      it 'renders the profile and shows a deactivation banner' do
        user = create(
          :user,
          :fully_registered,
          profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
        )
        user.active_profile.deactivate(:password_reset)

        sign_in user

        presenter = AccountShowPresenter.new(
          decrypted_pii: nil,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          user: user,
          locked_for_session: false,
          all_emails_requested: false,
          ial2_requested: false,
        )
        allow(subject).to receive(:presenter).and_return(presenter)

        get :show

        expect(response).to_not be_redirect
      end
    end

    context 'when a user is suspended' do
      it 'redirects to contact support page' do
        user = create(:user, :fully_registered, :suspended)

        sign_in user
        get :show

        expect(response).to redirect_to(user_please_call_url)
      end
    end

    context 'when logging in with piv/cac' do
      context 'when the user is proofed' do
        it 'renders a locked profile' do
          user = create(
            :user,
            :fully_registered,
            profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
          )

          sign_in user

          presenter = AccountShowPresenter.new(
            decrypted_pii: nil,
            sp_session_request_url: nil,
            authn_context: nil,
            sp_name: nil,
            user: user,
            locked_for_session: false,
            all_emails_requested: false,
            ial2_requested: false,
          )
          allow(subject).to receive(:presenter).and_return(presenter)

          get :show

          expect(response).to_not be_redirect
        end
      end
    end

    context 'user is not authenticated' do
      it 'redirects to sign in page with relevant flash message' do
        get :show
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(t('devise.failure.unauthenticated'))
      end
    end
  end

  describe '#reauthentication' do
    let(:user) { create(:user, :fully_registered) }
    before(:each) do
      stub_sign_in(user)
    end

    it 'redirects to 2FA options' do
      post :reauthentication

      expect(response).to redirect_to login_two_factor_options_url
    end

    it 'sets context to authentication' do
      post :reauthentication

      expect(controller.user_session[:context]).to eq 'reauthentication'
    end

    it 'sets stored location for redirecting' do
      post :reauthentication

      expect(controller.user_session[:stored_location]).to eq account_url
    end

    context 'with parameters' do
      let(:params) { { foo: 'bar' } }

      it 'sets stored location excluding unknown parameters' do
        post :reauthentication, params: params

        expect(controller.user_session[:stored_location]).to eq account_url
      end

      context 'with permitted parameters' do
        let(:manage_authenticator_param) { 'abc-123' }
        let(:params) { { foo: 'bar', manage_authenticator: manage_authenticator_param } }

        it 'sets stored location including only permitted parameters' do
          post :reauthentication, params: params

          expect(controller.user_session[:stored_location]).to eq(
            account_url(manage_authenticator: manage_authenticator_param),
          )
        end
      end
    end
  end
end
