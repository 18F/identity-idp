require 'rails_helper'

RSpec.describe Users::WebauthnPlatformRecommendedController do
  let(:user) { create(:user) }

  before do
    stub_sign_in(user) if user
  end

  it 'includes appropriate before_actions' do
    expect(controller).to have_actions(
      :before,
      :confirm_two_factor_authenticated,
      :apply_secure_headers_override,
    )
  end

  describe '#new' do
    subject(:response) { get :new }

    it 'assigns sign_in_flow instance variable from session' do
      controller.session[:sign_in_flow] = :example

      response

      expect(assigns(:sign_in_flow)).to eq(:example)
    end

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(:webauthn_platform_recommended_visited)
    end
  end

  describe '#create' do
    let(:params) { {} }
    subject(:response) { post :create, params: params }

    it 'logs analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        :webauthn_platform_recommended_submitted,
        opted_to_add: false,
      )
    end

    it 'updates user record to mark as having dismissed recommendation' do
      freeze_time do
        expect { response }.to change { user.webauthn_platform_recommended_dismissed_at }.
          from(nil).
          to(Time.zone.now)
      end
    end

    it 'does not assign recommended session value' do
      expect { response }.not_to change { controller.user_session[:webauthn_platform_recommended] }.
        from(nil)
    end

    it 'redirects user to after sign in path' do
      expect(controller).to receive(:after_sign_in_path_for).with(user).and_return(account_path)

      expect(response).to redirect_to(account_path)
    end

    context 'user is creating account' do
      before do
        allow(controller).to receive(:in_account_creation_flow?).and_return(true)
        allow(controller).to receive(:next_setup_path).and_return(sign_up_completed_path)
      end

      it 'redirects user to set up next authenticator' do
        expect(response).to redirect_to(sign_up_completed_path)
      end
    end

    context 'user opted to add' do
      let(:params) { { add_method: 'true' } }

      it 'logs analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :webauthn_platform_recommended_submitted,
          opted_to_add: true,
        )
      end

      it 'redirects user to set up platform authenticator' do
        expect(response).to redirect_to(webauthn_setup_path(platform: true))
      end

      it 'assigns recommended session value to recommendation flow' do
        expect { response }.to change { controller.user_session[:webauthn_platform_recommended] }.
          from(nil).to(:authentication)
      end

      context 'user is creating account' do
        before do
          allow(controller).to receive(:in_account_creation_flow?).and_return(true)
        end

        it 'assigns recommended session value to recommendation flow' do
          expect { response }.to change { controller.user_session[:webauthn_platform_recommended] }.
            from(nil).to(:account_creation)
        end
      end
    end
  end
end
