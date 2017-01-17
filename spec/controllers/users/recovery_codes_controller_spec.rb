require 'rails_helper'

describe Users::RecoveryCodesController do
  describe '#show' do
    context 'when user signed in' do
      before do
        stub_sign_in
      end

      it 'tracks an analytics event' do
        stub_analytics

        expect(@analytics).to receive(:track_event).with(Analytics::PROFILE_RECOVERY_CODE_CREATE)

        get :show
      end

      it 'generates a new recovery code' do
        generator = instance_double(RecoveryCodeGenerator)
        allow(RecoveryCodeGenerator).to receive(:new).
          with(subject.current_user).and_return(generator)

        expect(generator).to receive(:create)

        get :show
      end

      it 'populates the flash when resending code' do
        expect(flash[:sucess]).to be_nil

        get :show, resend: true
        expect(flash[:success]).to eq t('notices.send_code.recovery_code')
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
