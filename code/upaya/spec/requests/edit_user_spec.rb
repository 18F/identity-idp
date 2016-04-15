include Features::MailerHelper

describe 'user edits their account', email: true do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_with_mobile) { create(:user, :signed_up, :with_mobile) }

  def sign_in_as_a_valid_user(user)
    @user ||= user

    post_via_redirect(
      new_user_session_path,
      'user[email]' => @user.email,
      'user[password]' => @user.password
    )

    patch_via_redirect(
      user_two_factor_authentication_path,
      'code' => @user.otp_code
    )
  end

  let(:new_email) { 'new_email@example.com' }
  let(:attrs_with_new_email) do
    {
      email: new_email,
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_for_new_mobile) do
    {
      email: @user.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: SecondFactor.pluck(:id)
    }
  end

  let(:attrs_with_email_2fa) do
    {
      email: @user.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  shared_examples 'changing_email' do
    it 'displays a notice informing the user their email has been confirmed when user confirms' do
      get_via_redirect links_in_email(last_email).first

      expect(flash[:notice]).to eq t 'devise.confirmations.confirmed'
      expect(response).to render_template('user_mailer/email_changed')
    end

    it 'calls EmailNotifier when user confirms their new email' do
      notifier = instance_double(EmailNotifier)

      expect(EmailNotifier).to receive(:new).with(user).and_return(notifier)
      expect(notifier).to receive(:send_email_changed_email)

      get_via_redirect links_in_email(last_email).first
    end

    it 'confirms email when user clicks link in email while signed out' do
      delete_via_redirect destroy_user_session_path
      get_via_redirect links_in_email(last_email).first

      expect(flash[:notice]).to eq t 'devise.confirmations.confirmed'
    end
  end

  context 'user changes email address' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect '/users', id: @user, user: attrs_with_new_email
    end

    it_behaves_like 'changing_email'
  end

  context 'user changes mobile' do
    before do
      sign_in_as_a_valid_user(user_with_mobile)
      @old_otp_code = @user.otp_code
      patch_via_redirect '/users', id: @user, user: attrs_for_new_mobile
    end

    it 'deletes unconfirmed number after log out if not confirmed' do
      delete_via_redirect destroy_user_session_path

      expect(@user.reload.unconfirmed_mobile).to_not be_present
    end

    it 'does not disable mobile 2FA after log out if user has mobile' do
      delete_via_redirect destroy_user_session_path
      post_via_redirect(
        new_user_session_path,
        'user[email]' => @user.email,
        'user[password]' => @user.password
      )

      expect(@user.reload.second_factors.pluck(:name)).to include('Mobile')
    end

    it 'does not allow the login OTP to be used for confirmation' do
      patch_via_redirect(user_two_factor_authentication_path, 'code' => @old_otp_code)

      expect(response.body).to match(/Secure one-time password is invalid./)
      expect(@user.reload.mobile).to_not eq '+1 (555) 555-5555'
    end

    it 'sends SMS to old number, then changes current number once confirmed' do
      expect(SmsSenderNumberChangeJob).to receive(:perform_later).with(@user)
      expect(@user.reload.mobile).to eq '+1 (500) 555-0006'

      patch_via_redirect(user_two_factor_authentication_path, 'code' => @user.reload.otp_code)

      expect(@user.reload.mobile).to eq '+1 (555) 555-5555'
    end

    it 'does not change the current number if incorrect code is entered' do
      patch_via_redirect(user_two_factor_authentication_path, 'code' => '12345678')

      expect(@user.reload.mobile).to_not eq '+1 (555) 555-5555'
    end
  end

  context 'user adds a new mobile number but not mobile 2FA' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect '/users', id: @user, user: attrs_with_email_2fa
    end

    it 'deletes unconfirmed number after log out if not confirmed' do
      delete_via_redirect destroy_user_session_path

      expect(@user.reload.unconfirmed_mobile).to_not be_present
    end
  end

  context 'user changes mobile to an existing mobile' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        id: @user,
        user: attrs_for_new_mobile.merge!(
          mobile: user_with_mobile.mobile
        )
      )
    end

    it 'lets user know they need to confirm their new mobile', sms: true do
      expect(response.body).
        to include("A one-time password has been sent to #{user.reload.unconfirmed_mobile}.")
      expect(flash[:notice]).to eq t('devise.registrations.mobile_update_needs_confirmation')
      expect(user.reload.mobile).to be_nil
      expect(SmsSenderExistingMobileJob).to have_been_enqueued.with(global_id(user_with_mobile))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user))
    end
  end

  context 'user changes both email and mobile to existing email and mobile' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        id: @user,
        user: attrs_for_new_mobile.merge!(
          mobile: user_with_mobile.mobile,
          email: user_with_mobile.email
        )
      )
    end

    it 'lets user know they need to confirm both their new mobile and email', sms: true do
      expect(response.body).
        to include("A one-time password has been sent to #{user.reload.unconfirmed_mobile}.")
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(user.reload.mobile).to be_nil
      expect(SmsSenderExistingMobileJob).to have_been_enqueued.with(global_id(user_with_mobile))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
      expect(last_email.subject).to eq 'Email Confirmation Notification'
    end
  end

  context 'user changes email to nonexistent email and mobile to existing mobile' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        id: @user,
        user: attrs_with_new_email.merge!(
          mobile: user_with_mobile.mobile,
          second_factor_ids: SecondFactor.pluck(:id)
        )
      )
    end

    it 'lets user know they need to confirm both their new mobile and email', sms: true do
      expect(response.body).
        to include("A one-time password has been sent to #{user.reload.unconfirmed_mobile}.")
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(user.reload.mobile).to be_nil
      expect(SmsSenderExistingMobileJob).to have_been_enqueued.with(global_id(user_with_mobile))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
      expect(last_email.subject).to eq 'Email confirmation instructions'
    end

    it_behaves_like 'changing_email'
  end

  context 'user changes email to existing email and mobile to nonexistent mobile' do
    before do
      sign_in_as_a_valid_user(user)
      patch_via_redirect(
        '/users',
        user: attrs_for_new_mobile.merge!(
          email: user_with_mobile.email
        )
      )
    end

    it 'lets user know they need to confirm both their new mobile and email', sms: true do
      expect(response.body).
        to include("A one-time password has been sent to #{user.reload.unconfirmed_mobile}.")
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(user.reload.mobile).to be_nil
      expect(SmsSenderExistingMobileJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
      expect(SmsSenderOtpJob).to have_been_enqueued.with(global_id(user))
      expect(last_email.subject).to eq 'Email Confirmation Notification'
    end
  end
end
