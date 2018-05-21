require 'rails_helper'

RSpec.describe SignUp::EmailResendController do
  describe '#create' do
    context 'user exists and is not confirmed' do
      it 'sends confirmation email to user and redirects to sign_up_verify_email_path' do
        user = create(:user, :unconfirmed)
        user_params = { resend_email_confirmation_form: { email: user.email } }

        stub_analytics
        result = {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND, result)

        expect { post :create, params: user_params }.
          to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to sign_up_verify_email_path
      end
    end

    context 'user does not exist' do
      before do
        @user_params = { resend_email_confirmation_form: { email: 'nonexistent@test.com' } }
      end

      it 'does not send an email and displays the same message as if the user existed' do
        expect { post :create, params: @user_params }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to redirect_to sign_up_verify_email_path
      end

      it 'tracks event with nonexistent user' do
        stub_analytics
        result = {
          success: true,
          errors: {},
          user_id: 'nonexistent-uuid',
          confirmed: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND, result)

        post :create, params: @user_params
      end
    end

    context 'user exists and is confirmed' do
      it 'does not send confirmation email to user and redirects to sign_up_verify_email_path' do
        user = create(:user)
        user_params = { resend_email_confirmation_form: { email: user.email } }

        stub_analytics
        result = {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: true,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND, result)

        expect { post :create, params: user_params }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to redirect_to sign_up_verify_email_path
      end
    end

    context 'email is invalid' do
      it 'renders new' do
        user_params = { resend_email_confirmation_form: { email: 'a@b.' } }

        post :create, params: user_params

        expect(response).to render_template(:new)
      end
    end

    context 'email is capitalized and/or contains spaces' do
      it 'sends an email' do
        create(:user, :unconfirmed, email: 'test@example.com')

        user_params = { resend_email_confirmation_form: { email: 'TEST@example.com ' } }

        expect { post :create, params: user_params }.
          to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    it 'renders new if email is a Hash' do
      user_params = {
        resend_email_confirmation_form: { email: { foo: 'bar' } },
      }
      post :create, params: user_params

      expect(response).to render_template(:new)
    end
  end
end
