require 'rails_helper'

include Features::LocalizationHelper
include Features::MailerHelper

describe Users::EmailsController do
  describe '#update' do
    let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
    let(:second_user) { create(:user, :signed_up, email: 'another@example.com') }
    let(:new_email) { 'new_email@example.com' }

    context 'user changes email' do
      it 'lets user know they need to confirm their new email' do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        analytics_hash = {
          success: true,
          errors: [],
          email_already_exists: false,
          email_changed: true
        }

        put :update, update_user_email_form: { email: new_email }

        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
        expect(response).to render_template('devise/mailer/confirmation_instructions')
        expect(user.reload.email).to eq 'old_email@example.com'
        expect(@analytics).to have_received(:track_event).
          with(Analytics::EMAIL_CHANGE_REQUEST, analytics_hash)
      end
    end

    context 'user enters an empty email address' do
      render_views

      it 'displays an error message and does not delete the email' do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        analytics_hash = {
          success: false,
          errors: [t('valid_email.validations.email.invalid')],
          email_already_exists: false,
          email_changed: false
        }

        put :update, update_user_email_form: { email: '' }

        expect(response.body).to have_content invalid_email_message
        expect(user.reload.email).to be_present
        expect(@analytics).to have_received(:track_event).
          with(Analytics::EMAIL_CHANGE_REQUEST, analytics_hash)
      end
    end

    context "user changes email to another user's email address" do
      it 'lets user know they need to confirm their new email' do
        stub_sign_in

        stub_analytics
        allow(@analytics).to receive(:track_event)

        analytics_hash = {
          success: true,
          errors: [],
          email_already_exists: true,
          email_changed: true
        }

        put :update, update_user_email_form: { email: second_user.email.upcase }

        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
        expect(response).to render_template('user_mailer/signup_with_your_email')
        expect(last_email.subject).to eq t('mailer.email_reuse_notice.subject')
        expect(@analytics).to have_received(:track_event).
          with(Analytics::EMAIL_CHANGE_REQUEST, analytics_hash)
      end
    end

    context 'user updates with invalid email' do
      render_views

      it 'displays error about invalid email' do
        stub_sign_in(user)
        stub_analytics
        allow(@analytics).to receive(:track_event)

        analytics_hash = {
          success: false,
          errors: [t('valid_email.validations.email.invalid')],
          email_already_exists: false,
          email_changed: false
        }

        put :update, update_user_email_form: { email: 'foo' }

        expect(response.body).to have_content(t('valid_email.validations.email.invalid'))
        expect(@analytics).to have_received(:track_event).
          with(Analytics::EMAIL_CHANGE_REQUEST, analytics_hash)
      end
    end

    context 'user submits the form without changing their email' do
      render_views

      it 'redirects to profile page without any messages' do
        stub_sign_in(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        analytics_hash = {
          success: true,
          errors: [],
          email_already_exists: false,
          email_changed: false
        }

        put :update, update_user_email_form: { email: user.email }

        expect(response).to redirect_to profile_url
        expect(flash.keys).to be_empty
        expect(@analytics).to have_received(:track_event).
          with(Analytics::EMAIL_CHANGE_REQUEST, analytics_hash)
      end
    end
  end
end
