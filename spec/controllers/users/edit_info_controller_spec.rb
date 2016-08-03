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

  describe '#mobile' do
    let(:user) { create(:user, :signed_up, mobile: '+1 (202) 555-1234') }
    let(:second_user) { create(:user, :signed_up, mobile: '+1 (202) 555-5678') }
    let(:new_mobile) { '555-555-5555' }

    context 'user changes mobile' do
      before do
        sign_in(user)
        stub_analytics(user)
        allow(@analytics).to receive(:track_event)
        put :mobile, update_user_mobile_form: { mobile: new_mobile }
      end

      it 'redirects to phone confirmation page with success message' do
        expect(response).to redirect_to(phone_confirmation_send_path)
        expect(flash[:notice]).to eq t('devise.registrations.mobile_update_needs_confirmation')
      end

      it 'does not update the users phone number' do
        expect(user.reload.mobile).to_not eq '+1 (555) 555-5555'
      end

      it 'tracks the phone number update event' do
        expect(@analytics).to have_received(:track_event).
          with('User asked to update their phone number')
      end
    end

    context 'user attempts to remove mobile number' do
      render_views

      it 'displays error message and does not remove mobile' do
        sign_in(user)
        put :mobile, update_user_mobile_form: { mobile: '' }

        expect(response.body).to have_content invalid_mobile_message
        expect(second_user.reload.mobile).to be_present
      end
    end

    context "user changes mobile to another user's mobile" do
      it 'redirects to phone confirmation page with success message' do
        sign_in(user)
        put :mobile, update_user_mobile_form: { mobile: second_user.mobile }

        expect(response).to redirect_to(phone_confirmation_send_path)
        expect(flash[:notice]).to eq t('devise.registrations.mobile_update_needs_confirmation')
        expect(user.reload.mobile).to_not eq second_user.mobile
      end
    end

    context 'user updates with invalid mobile' do
      render_views

      it 'displays error about invalid mobile' do
        sign_in(user)
        put :mobile, update_user_mobile_form: { mobile: '123' }

        expect(response.body).to have_content('number is invalid')
      end
    end
  end
end
