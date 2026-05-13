require 'rails_helper'

RSpec.describe PasswordCaptureController do
  describe '#update' do
    let(:user) { create(:user, :fully_registered, password: 'a really long sekrit') }

    context 'form returns success' do
      let(:pii) { { first_name: 'Jane', ssn: '111-11-1111' } }

      before do
        allow(controller).to receive(:cache_user_proofing_events).and_return(double)
      end

      it 'decrypts PII and redirects' do
        create(:profile, :active, :verified, user: user, pii: pii)

        stub_sign_in(user)

        expect(controller.user_session[:encrypted_profiles]).to be nil
        expect(controller).to_not have_received(:cache_user_proofing_events)

        params = { password: 'a really long sekrit' }
        get :new
        patch :create, params: { user: params }

        expect(response).to redirect_to account_path
        expect(controller.user_session[:encrypted_profiles]).to_not be nil
        expect(controller).to have_received(:cache_user_proofing_events)
      end
    end

    context 'form errors' do
      it 'increases password attempts' do
        stub_sign_in(user)

        params = { password: 'a wrong password' }
        get :new
        patch :create, params: { user: params }

        expect(controller.session[:password_attempts]).to eq 1
        expect(response).to redirect_to capture_password_path
      end
    end
  end
end
