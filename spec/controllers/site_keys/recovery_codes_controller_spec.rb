require 'rails_helper'

RSpec.describe SiteKeys::RecoveryCodesController do
  let(:user) { create(:user, :fully_registered) }
  let(:vault) { SiteKeys::Vault.new(user:, user_session: controller.user_session) }

  before do
    allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
    stub_sign_in(user)
    stub_analytics
  end

  describe 'before_actions' do
    it 'requires a fully authenticated, recently authenticated user' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_recently_authenticated_2fa,
        :redirect_if_recoverable,
      )
    end
  end

  describe 'the acknowledgement form' do
    render_views

    it 'submits the checkbox as the acknowledgment param' do
      vault.unlock(user.password, create: true)

      get :show

      expect(response.body).to include('name="acknowledgment"')
    end
  end

  describe '#show' do
    context 'with a pending recovery code' do
      before { vault.unlock(user.password, create: true) }

      it 'shows the code' do
        get :show

        expect(assigns(:code)).to eq(vault.pending_recovery_code)
        expect(@analytics).to have_logged_event(:site_key_recovery_code_viewed, present: true)
      end
    end

    context 'with an unlocked root whose code was never acknowledged' do
      before do
        create_site_key_root(user, acknowledge: false)
        vault.unlock(user.password, show_recovery_code: false)
      end

      it 'shows a fresh code' do
        get :show

        expect(assigns(:code)).to be_present
      end
    end

    context 'without a pending recovery code' do
      it 'redirects to the account page' do
        get :show

        expect(response).to redirect_to(account_url)
      end
    end

    context 'when the root was deleted by another session' do
      before do
        vault.unlock(user.password, create: true)
        SiteKeyRoot.where(user:).delete_all
        user.reload
      end

      it 'continues without showing a code' do
        get :show

        expect(response).to redirect_to(account_url)
      end
    end
  end

  describe '#update' do
    before { vault.unlock(user.password, create: true) }

    it 'records the acknowledgement' do
      put :update, params: { acknowledgment: '1' }

      expect(user.reload.site_key_root.recovery_code_acknowledged_at).to be_present
      expect(@analytics).to have_logged_event(:site_key_recovery_code_acknowledged, matched: true)
    end

    it 'continues' do
      put :update, params: { acknowledgment: '1' }

      expect(response).to redirect_to(account_url)
    end

    it 'shows the code again without the acknowledgment checkbox' do
      put :update

      expect(response).to redirect_to(site_key_recovery_code_url)
      expect(user.reload.site_key_root.recovery_code_acknowledged_at).to be_nil
    end
  end

  describe '#new' do
    before do
      vault.unlock(user.password, create: true)
      vault.acknowledge_recovery_code
    end

    it 'renders the confirmation page' do
      get :new

      expect(response).to render_template(:new)
      expect(@analytics).to have_logged_event(:site_key_recovery_code_new_visited)
    end

    context 'when the root awaits recovery' do
      before do
        user.site_key_root.forget_password!
        controller.user_session.delete(SiteKeys::Vault::SESSION_KEY)
      end

      it 'redirects to the recovery page' do
        get :new

        expect(response).to redirect_to(site_key_recovery_url)
      end
    end
  end

  describe '#create' do
    context 'when the root is unlocked' do
      before do
        vault.unlock(user.password, create: true)
        vault.acknowledge_recovery_code
      end

      it 'mints a new code and shows it' do
        post :create

        expect(response).to redirect_to(site_key_recovery_code_url)
        expect(vault.pending_recovery_code).to be_present
        expect(@analytics).to have_logged_event(:site_key_recovery_code_regenerated)
      end
    end

    context 'when the root is locked' do
      before { create_site_key_root(user) }

      it 'asks for the password and returns to the confirmation page' do
        post :create

        expect(response).to redirect_to(capture_password_url)
        expect(controller.user_session[:stored_location]).to eq(new_site_key_recovery_code_url)
      end
    end
  end
end
