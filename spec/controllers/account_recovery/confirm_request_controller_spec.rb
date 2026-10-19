require 'rails_helper'

RSpec.describe AccountRecovery::ConfirmRequestController do
  let(:user) { create(:user, :fully_registered) }

  describe '#show' do
    it 'redirects to root without an email in the flash' do
      stub_sign_in_before_2fa(user)

      get :show

      expect(response).to redirect_to(root_url)
    end

    context 'with an email in the flash' do
      before do
        stub_sign_in_before_2fa(user)
        allow(controller).to receive(:flash).and_return(email: user.email)
      end

      it 'renders the confirmation and signs the user out' do
        expect(controller).to receive(:sign_out)

        get :show

        expect(response).to render_template(:show)
      end

      it 'passes only the sign-in email to the simple confirmation' do
        expect(controller).to receive(:render).with(
          :show,
          locals: { email: user.email },
        ).and_call_original

        get :show
      end
    end
  end
end
