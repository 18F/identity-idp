require 'rails_helper'

include Features::MailerHelper
include Features::LocalizationHelper

describe Users::EditInfoController, devise: true do
  describe '#email' do
    let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
    let(:second_user) { create(:user, :signed_up, email: 'another@example.com') }
    let(:new_email) { 'new_email@example.com' }

    context 'user changes email' do
      before do
        sign_in(user)
        put :email, update_user_email_form: { email: new_email }
      end

      it 'lets user know they need to confirm their new email' do
        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
        expect(response).to render_template('devise/mailer/confirmation_instructions')
        expect(user.reload.email).to eq 'old_email@example.com'
      end
    end

    context 'user attempts enter empty email address' do
      render_views

      it 'displays an error message and does not delete the email' do
        sign_in(user)
        put :email, update_user_email_form: { email: '' }

        expect(response.body).to have_content invalid_email_message
        expect(user.reload.email).to be_present
      end
    end

    context "user changes email to another user's email address" do
      it 'lets user know they need to confirm their new email' do
        sign_in(user)
        put :email, update_user_email_form: { email: second_user.email }

        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
        expect(response).to render_template('user_mailer/signup_with_your_email')
        expect(user.reload.email).to eq 'old_email@example.com'
        expect(last_email.subject).to eq t('mailer.email_reuse_notice.subject')
      end
    end

    context 'user updates with invalid email' do
      render_views

      it 'displays error about invalid email' do
        sign_in(user)
        put :email, update_user_email_form: { email: 'foo' }

        expect(response.body).to have_content('Please enter a valid email')
      end
    end
  end

  describe '#phone' do
    let(:user) { create(:user, :signed_up, phone: '+1 (202) 555-1234') }
    let(:second_user) { create(:user, :signed_up, phone: '+1 (202) 555-5678') }
    let(:new_phone) { '555-555-5555' }

    context 'user changes phone' do
      before do
        sign_in(user)
        stub_analytics
        allow(@analytics).to receive(:track_event)
        put :phone, update_user_phone_form: { phone: new_phone }
      end

      it 'redirects to phone confirmation page with success message' do
        expect(response).to redirect_to(phone_confirmation_send_path)
        expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
      end

      it 'does not update the users phone number' do
        expect(user.reload.phone).to_not eq '+1 (555) 555-5555'
      end

      it 'tracks the phone number update event' do
        expect(@analytics).to have_received(:track_event).
          with('User asked to update their phone number')
      end
    end

    context 'user attempts to remove phone number' do
      render_views

      it 'displays error message and does not remove phone' do
        sign_in(user)
        put :phone, update_user_phone_form: { phone: '' }

        expect(response.body).to have_content invalid_phone_message
        expect(second_user.reload.phone).to be_present
      end
    end

    context "user changes phone to another user's phone" do
      it 'redirects to phone confirmation page with success message' do
        sign_in(user)
        put :phone, update_user_phone_form: { phone: second_user.phone }

        expect(response).to redirect_to(phone_confirmation_send_path)
        expect(flash[:notice]).to eq t('devise.registrations.phone_update_needs_confirmation')
        expect(user.reload.phone).to_not eq second_user.phone
      end
    end

    context 'user updates with invalid phone' do
      render_views

      it 'displays error about invalid phone' do
        sign_in(user)
        put :phone, update_user_phone_form: { phone: '123' }

        expect(response.body).to have_content('number is invalid')
      end
    end
  end
end
