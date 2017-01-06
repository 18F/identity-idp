require 'rails_helper'

RSpec.describe SignUp::EmailResendController do
  describe '#create' do
    context 'user exists and is not confirmed' do
      it 'sends confirmation email to user and redirects to root' do
        user = create(:user, :unconfirmed)

        user_params = { user: { email: user.email } }

        expect { post :create, user_params }.
          to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to root_url
        expect(flash[:notice]).to eq t('devise.confirmations.send_paranoid_instructions')
      end
    end

    context 'user does not exist' do
      it 'does not send an email and displays the same message as if the user existed' do
        user_params = { user: { email: 'nonexistent@test.com' } }

        expect { post :create, user_params }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to redirect_to root_url
        expect(flash[:notice]).to eq t('devise.confirmations.send_paranoid_instructions')
      end
    end
  end
end
