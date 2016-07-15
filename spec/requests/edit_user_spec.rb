require 'rails_helper'

include Features::MailerHelper
include Features::ActiveJobHelper

describe 'user edits their account', email: true do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_with_mobile) { create(:user, :signed_up, mobile: '+1 (202) 555-1213') }

  def user_session
    session['warden.user.user.session']
  end

  def sign_in_as_a_valid_user(user)
    @user ||= user

    post_via_redirect(
      new_user_session_path,
      'user[email]' => @user.email,
      'user[password]' => @user.password
    )

    if @user.reload.direct_otp
      patch_via_redirect(
        user_two_factor_authentication_path,
        'code' => @user.direct_otp
      )
    end
  end

  let(:new_email) { 'new_email@example.com' }
  let(:attrs_with_new_email) do
    {
      email: new_email,
      mobile: user.mobile,
      current_password: '!1aZ' * 32,
      password: ''
    }
  end

  let(:attrs_for_new_mobile) do
    {
      email: @user.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      password: ''
    }
  end

  shared_examples 'changing_email' do
    it 'displays a notice informing the user their email has been confirmed when user confirms' do
      get_via_redirect parse_email_for_link(last_email, /confirmation_token/)

      expect(flash[:notice]).to eq t('devise.confirmations.confirmed')
      expect(response).to render_template('user_mailer/email_changed')
    end

    it 'calls EmailNotifier when user confirms their new email' do
      notifier = instance_double(EmailNotifier)

      expect(EmailNotifier).to receive(:new).with(user).and_return(notifier)
      expect(notifier).to receive(:send_email_changed_email)

      get_via_redirect parse_email_for_link(last_email, /confirmation_token/)
    end

    it 'confirms email when user clicks link in email while signed out' do
      delete_via_redirect destroy_user_session_path
      get_via_redirect parse_email_for_link(last_email, /confirmation_token/)

      expect(flash[:notice]).to eq t('devise.confirmations.confirmed')
    end

    it 'tracks the confirmation event' do
      stub_analytics(user)

      expect(@analytics).to receive(:track_event).
        with('Email changed and confirmed', user)

      get_via_redirect parse_email_for_link(last_email, /confirmation_token/)
    end
  end

  context 'user changes email address' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect '/users', update_user_profile_form: attrs_with_new_email
    end

    it_behaves_like 'changing_email'
  end

  context 'user changes mobile' do
    before do
      sign_in_as_a_valid_user(user_with_mobile)
      @old_otp_code = @user.direct_otp
      patch_via_redirect '/users', update_user_profile_form: attrs_for_new_mobile
    end

    it 'does not allow the OTP to be used for confirmation' do
      put_via_redirect(phone_confirmation_path, 'code' => @old_otp_code)

      expect(response.body).to match(/Invalid confirmation code/)
      expect(@user.reload.mobile).to_not eq '+1 (555) 555-5555'
    end

    it 'sends SMS to old number, then changes current number once confirmed' do
      expect(SmsSenderNumberChangeJob).to receive(:perform_later).with('+1 (202) 555-1213')

      put_via_redirect(phone_confirmation_path, 'code' => user_session[:phone_confirmation_code])
      expect(@user.reload.mobile).to eq '+1 (555) 555-5555'
    end

    it 'does not change the current number if incorrect code is entered' do
      patch_via_redirect(user_two_factor_authentication_path, 'code' => '12345678')

      expect(@user.reload.mobile).to_not eq '+1 (555) 555-5555'
    end
  end

  context 'user changes mobile to an existing mobile' do
    it 'lets user know they need to confirm their new mobile' do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_for_new_mobile.merge!(
          mobile: user_with_mobile.mobile
        )
      )

      expect(response.body).
        to include(
          'A confirmation code has been sent to <strong>+1 (202) 555-1213</strong>.'
        )
      expect(flash[:notice]).to eq t('devise.registrations.mobile_update_needs_confirmation')

      expect(user.reload.mobile).to eq '+1 (202) 555-1212'
    end

    it 'calls SmsSenderExistingMobileJob but not SmsSenderOtpJob' do
      sign_in_as_a_valid_user(user)

      expect(SmsSenderExistingMobileJob).to receive(:perform_later).with(user_with_mobile.mobile)
      expect(SmsSenderOtpJob).to_not receive(:perform_later)

      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_for_new_mobile.merge!(
          mobile: user_with_mobile.mobile
        )
      )
    end
  end

  context 'user changes both email and mobile to existing email and mobile' do
    it 'lets user know they need to confirm both their new mobile and email' do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_for_new_mobile.merge!(
          mobile: user_with_mobile.mobile,
          email: user_with_mobile.email
        )
      )

      expect(response.body).
        to include(
          'A confirmation code has been sent to <strong>+1 (202) 555-1213</strong>.'
        )
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(user.reload.mobile).to eq '+1 (202) 555-1212'
      expect(last_email.subject).to eq t('mailer.email_reuse_notice.subject')
      expect(number_of_emails_sent).to eq 1
    end

    it 'calls SmsSenderExistingMobileJob but not SmsSenderOtpJob' do
      sign_in_as_a_valid_user(user)

      expect(SmsSenderExistingMobileJob).to receive(:perform_later).with(user_with_mobile.mobile)
      expect(SmsSenderOtpJob).to_not receive(:perform_later)

      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_for_new_mobile.merge!(
          mobile: user_with_mobile.mobile,
          email: user_with_mobile.email
        )
      )
    end
  end

  context 'user changes email to nonexistent email and mobile to existing mobile' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_with_new_email.merge!(mobile: user_with_mobile.mobile)
      )
    end

    it 'lets user know they need to confirm both their new mobile and email' do
      expect(response.body).
        to include(
          'A confirmation code has been sent to <strong>+1 (202) 555-1213</strong>.'
        )
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(last_email.subject).to eq 'Email confirmation instructions'
      expect(number_of_emails_sent).to eq 1
    end

    it_behaves_like 'changing_email'

    it 'calls SmsSenderExistingMobileJob but not SmsSenderOtpJob' do
      expect(SmsSenderExistingMobileJob).to receive(:perform_later).with(user_with_mobile.mobile)
      expect(SmsSenderOtpJob).to_not receive(:perform_later)

      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_with_new_email.merge!(mobile: user_with_mobile.mobile)
      )
    end
  end

  context 'user changes email to existing email and mobile to nonexistent mobile' do
    it 'lets user know they need to confirm both their new mobile and email' do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_for_new_mobile.merge!(email: user_with_mobile.email)
      )

      expect(response.body).
        to include('A confirmation code has been sent to <strong>+1 (555) 555-5555</strong>.')
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(user.reload.mobile).to eq '+1 (202) 555-1212'
      expect(last_email.subject).to eq t('mailer.email_reuse_notice.subject')
      expect(number_of_emails_sent).to eq 1
    end

    it 'calls SmsSenderConfirmationJob, but not SmsSenderExistingMobileJob' do
      sign_in_as_a_valid_user(user)

      allow(SmsSenderConfirmationJob).to receive(:perform_later)
      expect(SmsSenderExistingMobileJob).to_not receive(:perform_later)

      patch_via_redirect(
        '/users',
        update_user_profile_form: attrs_for_new_mobile.merge!(email: user_with_mobile.email)
      )
      expect(SmsSenderConfirmationJob).to have_received(:perform_later).
        with(user_session[:phone_confirmation_code], '+1 (555) 555-5555')
    end
  end
end
