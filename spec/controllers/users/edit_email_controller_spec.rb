require 'rails_helper'

include Features::LocalizationHelper
include Features::MailerHelper

describe Users::EditEmailController do
  describe '#update' do
    let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
    let(:second_user) { create(:user, :signed_up, email: 'another@example.com') }
    let(:new_email) { 'new_email@example.com' }

    context 'user changes email' do
      before do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, update_user_email_form: { email: new_email }
      end

      it 'lets user know they need to confirm their new email' do
        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
        expect(response).to render_template('devise/mailer/confirmation_instructions')
        expect(user.reload.email).to eq 'old_email@example.com'
        expect(@analytics).to have_received(:track_event).with('User asked to change their email')
      end
    end

    context 'user enters an empty email address' do
      render_views

      it 'displays an error message and does not delete the email' do
        stub_sign_in(user)
        put :update, update_user_email_form: { email: '' }

        expect(response.body).to have_content invalid_email_message
        expect(user.reload.email).to be_present
      end
    end

    context "user changes email to another user's email address" do
      it 'lets user know they need to confirm their new email' do
        stub_sign_in

        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :update, update_user_email_form: { email: second_user.email.upcase }

        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
        expect(response).to render_template('user_mailer/signup_with_your_email')
        expect(last_email.subject).to eq t('mailer.email_reuse_notice.subject')
        expect(@analytics).to have_received(:track_event).
          with('User attempted to change their email to an existing email')
      end
    end

    context 'user updates with invalid email' do
      render_views

      it 'displays error about invalid email' do
        stub_sign_in(user)
        put :update, update_user_email_form: { email: 'foo' }

        expect(response.body).to have_content('Please enter a valid email')
      end
    end

    context 'user submits the form without changing their email' do
      render_views

      it 'redirects to profile page without any messages' do
        stub_sign_in(user)
        put :update, update_user_email_form: { email: user.email }

        expect(response).to redirect_to profile_url
        expect(flash.keys).to be_empty
      end
    end
  end
end
