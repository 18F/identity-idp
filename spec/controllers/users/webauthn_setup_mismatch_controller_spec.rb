require 'rails_helper'

RSpec.describe Users::WebauthnSetupMismatchController do
  let(:user) { create(:user, :fully_registered, :with_webauthn) }
  let(:webauthn_mismatch_id) { user.webauthn_configurations.take.id }

  before do
    stub_sign_in(user) if user
    controller.user_session&.[]=(:webauthn_mismatch_id, webauthn_mismatch_id)
  end

  shared_examples 'a validated mismatch controller action' do
    it 'applies secure headers override' do
      expect(controller).to receive(:apply_secure_headers_override)

      response
    end

    context 'user is not signed in' do
      let(:user) { nil }

      it 'redirects user to sign in' do
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'user is not fully-authenticated' do
      let(:user) { nil }

      before do
        stub_sign_in_before_2fa(create(:user, :fully_registered))
      end

      it 'redirects user to authenticate' do
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    context 'user is not recently authenticated' do
      before do
        expire_reauthn_window
      end

      it 'redirects user to authenticate' do
        expect(response).to redirect_to(login_two_factor_options_url)
      end
    end

    context 'session configuration id is missing' do
      let(:webauthn_mismatch_id) { nil }

      it 'redirects to next setup path' do
        expect(response).to redirect_to(account_url)
      end
    end

    context 'session configuration id is invalid' do
      let(:webauthn_mismatch_id) { 1 }

      it 'redirects to next setup path' do
        expect(response).to redirect_to(account_url)
      end
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it_behaves_like 'a validated mismatch controller action'

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :webauthn_setup_mismatch_visited,
        configuration_id: webauthn_mismatch_id,
        platform_authenticator: false,
      )
    end

    it 'assigns presenter instance variable for view' do
      response

      presenter = assigns(:presenter)
      expect(presenter).to be_kind_of(WebauthnSetupMismatchPresenter)
      expect(presenter.configuration.id).to eq(webauthn_mismatch_id)
    end

    context 'with platform authenticator' do
      let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :webauthn_setup_mismatch_visited,
          configuration_id: webauthn_mismatch_id,
          platform_authenticator: true,
        )
      end
    end
  end

  describe '#update' do
    subject(:response) { patch :update }

    it_behaves_like 'a validated mismatch controller action'

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :webauthn_setup_mismatch_submitted,
        configuration_id: webauthn_mismatch_id,
        platform_authenticator: false,
        confirmed_mismatch: true,
      )
    end

    it 'redirects to next setup path' do
      expect(response).to redirect_to(account_url)
    end

    context 'with platform authenticator' do
      let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :webauthn_setup_mismatch_submitted,
          configuration_id: webauthn_mismatch_id,
          platform_authenticator: true,
          confirmed_mismatch: true,
        )
      end
    end
  end

  describe '#destroy' do
    subject(:response) { delete :destroy }

    it_behaves_like 'a validated mismatch controller action'

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :webauthn_setup_mismatch_submitted,
        success: true,
        configuration_id: webauthn_mismatch_id,
        platform_authenticator: false,
        confirmed_mismatch: false,
      )
    end

    it 'invalidates deleted authenticator' do
      expect(controller).to receive(:handle_successful_mfa_deletion)
        .with(event_type: :webauthn_key_removed)

      response
    end

    context 'if deletion is unsuccessful' do
      before do
        user.phone_configurations.delete_all
      end

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :webauthn_setup_mismatch_submitted,
          success: false,
          error_details: { configuration_id: { only_method: true } },
          configuration_id: webauthn_mismatch_id,
          platform_authenticator: false,
          confirmed_mismatch: false,
        )
      end

      it 'assigns presenter instance variable for view' do
        response

        presenter = assigns(:presenter)
        expect(presenter).to be_kind_of(WebauthnSetupMismatchPresenter)
        expect(presenter.configuration.id).to eq(webauthn_mismatch_id)
      end

      it 'flashes error message' do
        response

        expect(flash.now[:error]).to eq(t('errors.manage_authenticator.remove_only_method_error'))
      end

      it 'renders new view' do
        expect(response).to render_template(:show)
      end
    end

    context 'with platform authenticator' do
      let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :webauthn_setup_mismatch_submitted,
          success: true,
          configuration_id: webauthn_mismatch_id,
          platform_authenticator: true,
          confirmed_mismatch: false,
        )
      end
    end
  end
end
