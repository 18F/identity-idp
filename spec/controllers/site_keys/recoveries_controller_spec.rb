require 'rails_helper'

RSpec.describe SiteKeys::RecoveriesController do
  let(:user) { create(:user, :fully_registered) }
  let!(:created) do
    allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
    create_site_key_root(user)
  end

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe 'before_actions' do
    it 'requires a fully authenticated, recently authenticated user' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_recently_authenticated_2fa,
        :redirect_unless_recoverable,
      )
    end
  end

  context 'when the root does not need recovery' do
    it 'redirects to the account page' do
      get :new

      expect(response).to redirect_to(account_url)
    end
  end

  context 'after a password reset' do
    before { user.site_key_root.forget_password! }

    describe '#new' do
      it 'renders the form' do
        get :new

        expect(response).to render_template(:new)
        expect(@analytics).to have_logged_event(:site_key_recovery_visited)
      end
    end

    describe '#create' do
      let(:code) { created.recovery_code }

      before { post :create, params: { site_keys_recovery_form: { code: } } }

      it 'unlocks the root in the session' do
        vault = SiteKeys::Vault.new(user: user.reload, user_session: controller.user_session)

        expect(vault.site_key('urn:sp')).to eq(derive_site_key(created.root, 'urn:sp'))
      end

      it 'asks for the password to re-wrap the root' do
        expect(response).to redirect_to(capture_password_url)
      end

      it 'logs the submission' do
        expect(@analytics).to have_logged_event(:site_key_recovery_submitted, success: true)
      end

      context 'with a wrong code' do
        let(:code) { SiteKeys::RecoveryCode.generate }

        it 'renders the form again' do
          expect(response).to render_template(:new)
        end

        it 'logs the failure' do
          expect(@analytics).to have_logged_event(
            :site_key_recovery_submitted,
            success: false,
            error_details: { code: { site_key_recovery_code: true } },
          )
        end

        it 'leaves the root locked' do
          vault = SiteKeys::Vault.new(user: user.reload, user_session: controller.user_session)

          expect(vault.unlocked?).to eq(false)
        end
      end
    end

    describe '#create when rate limited' do
      before do
        allow(IdentityConfig.store).to receive(:site_key_recovery_max_attempts).and_return(2)
      end

      it 'renders the rate limited page and leaves the root locked' do
        post :create, params: { site_keys_recovery_form: { code: SiteKeys::RecoveryCode.generate } }
        post :create, params: { site_keys_recovery_form: { code: created.recovery_code } }

        expect(response).to render_template(:rate_limited)
        expect(SiteKeys::Vault.new(user:, user_session: controller.user_session).unlocked?)
          .to eq(false)
      end
    end

    describe '#confirm_destroy' do
      it 'renders the confirmation page' do
        get :confirm_destroy

        expect(response).to render_template(:confirm_destroy)
      end
    end

    describe '#destroy' do
      it 'deletes the root' do
        expect { delete :destroy }.to change { SiteKeyRoot.where(user:).count }.from(1).to(0)
      end

      it 'logs the event' do
        delete :destroy

        expect(@analytics).to have_logged_event(:site_key_recovery_abandoned)
      end

      it 'continues to the service provider' do
        allow(controller).to receive(:after_sign_in_path_for).and_return('/sp')

        delete :destroy

        expect(response).to redirect_to('/sp')
      end
    end
  end
end
