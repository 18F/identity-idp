require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PivCacMismatchController do
  let(:user) { create(:user, :with_piv_or_cac) }

  before do
    stub_sign_in_before_2fa(user) if user
  end

  describe '#show' do
    subject(:response) { get :show }

    context 'with user having piv as their only authentication method' do
      let(:user) { create(:user, :with_piv_or_cac) }

      it 'assigns has_other_authentication_methods as false' do
        response

        expect(assigns(:has_other_authentication_methods)).to eq(false)
      end

      it 'logs an analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :piv_cac_mismatch_visited,
          piv_cac_required: false,
          has_other_authentication_methods: false,
        )
      end
    end

    context 'with user having other authentication methods' do
      let(:user) { create(:user, :with_piv_or_cac, :with_phone) }

      it 'assigns has_other_authentication_methods as true' do
        response

        expect(assigns(:has_other_authentication_methods)).to eq(true)
      end

      it 'logs an analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :piv_cac_mismatch_visited,
          piv_cac_required: false,
          has_other_authentication_methods: true,
        )
      end
    end

    context 'with partner not requiring hspd12 authentication' do
      before do
        controller.session[:sp] = {
          issuer: SamlAuthHelper::SP_ISSUER,
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        }
      end

      it 'assigns piv_cac_required as false' do
        response

        expect(assigns(:piv_cac_required)).to eq(false)
      end

      it 'logs an analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :piv_cac_mismatch_visited,
          piv_cac_required: false,
          has_other_authentication_methods: false,
        )
      end
    end

    context 'with partner requiring hspd12 authentication' do
      before do
        controller.session[:sp] = {
          issuer: SamlAuthHelper::SP_ISSUER,
          acr_values: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
        }
      end

      it 'assigns piv_cac_required as true' do
        response

        expect(assigns(:piv_cac_required)).to eq(true)
      end

      it 'logs an analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :piv_cac_mismatch_visited,
          piv_cac_required: true,
          has_other_authentication_methods: false,
        )
      end
    end

    context 'if user is not signed in' do
      let(:user) { nil }

      it 'redirects user to sign in' do
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'if user is already authenticated' do
      let(:user) { nil }

      before do
        stub_sign_in
      end

      it 'redirects user to the signed in path' do
        expect(response).to redirect_to(account_path)
      end
    end
  end

  describe '#create' do
    let(:params) { {} }
    subject(:response) { post :create, params: params }

    context 'when user chooses to add piv' do
      let(:params) { { add_piv_cac_after_2fa: 'true' } }

      it 'assigns session value to add piv after authenticating' do
        response

        expect(controller.user_session[:add_piv_cac_after_2fa]).to eq(true)
      end

      it 'logs an analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :piv_cac_mismatch_submitted,
          add_piv_cac_after_2fa: true,
        )
      end
    end

    context 'when user chooses to skip adding piv' do
      let(:params) { {} }

      it 'assigns session value to skip adding piv after authenticating' do
        response

        expect(controller.user_session[:add_piv_cac_after_2fa]).to eq(false)
      end

      it 'logs an analytics event' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          :piv_cac_mismatch_submitted,
          add_piv_cac_after_2fa: false,
        )
      end
    end
  end
end
