include Features::MailerHelper
include Features::LocalizationHelper
include Features::ActiveJobHelper

describe Users::RegistrationsController, devise: true do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_with_mobile) do
    create(:user, :signed_up, :with_mobile, email: 'mobile@example.com')
  end
  let(:new_email) { 'new_email@example.com' }
  let!(:old_encrypted_password) { user.encrypted_password }

  let(:attrs_with_both_2fa) do
    {
      email: user.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: SecondFactor.pluck(:id)
    }
  end

  let(:attrs_with_no_2fa) do
    {
      email: user.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: []
    }
  end

  let(:attrs_with_new_email_and_mobile) do
    {
      email: new_email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: SecondFactor.pluck(:id)
    }
  end

  let(:attrs_for_new_mobile) do
    {
      email: user_with_mobile.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: SecondFactor.pluck(:id)
    }
  end

  let(:attrs_with_blank_mobile) do
    {
      email: user_with_mobile.email,
      mobile: '',
      current_password: '!1aZ' * 32,
      second_factor_ids: SecondFactor.pluck(:id)
    }
  end

  let(:attrs_with_new_email_2fa) do
    {
      email: user_with_mobile.email,
      mobile: user_with_mobile.mobile,
      current_password: '!1aZ' * 32,
      second_factor_ids: SecondFactor.pluck(:id)
    }
  end

  let(:attrs_with_blank_mobile_and_email_2fa) do
    {
      email: user_with_mobile.email,
      mobile: '',
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_with_mobile_and_email_2fa) do
    {
      email: user_with_mobile.email,
      mobile: user_with_mobile.mobile,
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_with_mobile_and_mobile_2fa) do
    {
      email: user_with_mobile.email,
      mobile: user_with_mobile.mobile,
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Mobile').id]
    }
  end

  let(:attrs_with_email_2fa) do
    {
      email: user.email,
      mobile: '555-555-5555',
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_with_new_email) do
    {
      email: new_email,
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_without_current_password) do
    {
      email: new_email,
      current_password: '',
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_with_blank_email) do
    {
      email: '',
      current_password: '!1aZ' * 32,
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_with_new_valid_password) do
    {
      email: user.email,
      current_password: '!1aZ' * 32,
      password: '@Aaaaaa1',
      password_confirmation: '@Aaaaaa1',
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  let(:attrs_with_new_invalid_password) do
    {
      email: user.email,
      current_password: '!1aZ' * 32,
      password: '123',
      password_confirmation: '123',
      second_factor_ids: [SecondFactor.find_by_name('Email').id]
    }
  end

  shared_examples 'adding_mobile' do
    it 'redirects to otp page with message', sms: true do
      expect(flash[:notice]).
        to eq t('devise.registrations.mobile_update_needs_confirmation')

      expect(response).to redirect_to user_two_factor_authentication_path

      expect(user.reload.second_factors.pluck(:name).sort).to eq %w(Email Mobile)

      expect(user.reload.mobile).to_not eq '+1 (555) 555-5555'

      expect(SmsSenderOtpJob).to have_been_enqueued.with(global_id(user))

      expect(SmsSenderNumberChangeJob).to_not have_been_enqueued
    end
  end

  shared_examples 'updating_profile' do
    it 'redirects to user edit page with flash notice' do
      expect(response).to redirect_to(edit_user_registration_path)

      expect(flash[:notice]).to eq t('devise.registrations.updated')
    end
  end

  shared_examples 'updating_mobile' do
    it 'redirects to otp page with success message' do
      expect(response).to redirect_to(user_two_factor_authentication_path)

      expect(flash[:notice]).
        to eq t('devise.registrations.mobile_update_needs_confirmation')

      expect(test_user.reload.mobile).to_not eq '+1 (555) 555-5555'
    end
  end

  shared_examples 'updating_both_email_and_mobile' do
    it 'redirects to otp page with success message' do
      expect(response).to redirect_to(user_two_factor_authentication_path)

      expect(flash[:notice]).
        to eq t('devise.registrations.email_and_mobile_need_confirmation')

      expect(test_user.reload.mobile).to_not eq '+1 (555) 555-5555'
    end
  end

  context 'user adds mobile' do
    before { sign_in(user) }

    it 'sends an OTP to unconfirmed mobile after update' do
      expect(MobileSecondFactor).to receive(:transmit).with(user)

      put :update, id: subject.current_user, user: attrs_with_both_2fa
    end

    it 'sends an OTP to new number even if mobile 2FA option is not checked' do
      expect(MobileSecondFactor).to receive(:transmit).with(user)

      put :update, id: subject.current_user, user: attrs_with_email_2fa
    end
  end

  context 'user updates existing mobile number', sms: true do
    before do
      user_with_mobile.mobile_confirm
      sign_in(user_with_mobile)
      reset_job_queues
      patch :update, id: subject.current_user, user: attrs_for_new_mobile
    end

    it_behaves_like 'updating_mobile' do
      let(:test_user) { user_with_mobile }
    end

    it 'updated unconfirmed_mobile and sends an OTP to the unconfirmed number' do
      expect(user_with_mobile.reload.unconfirmed_mobile).to eq '+1 (555) 555-5555'

      expect(SmsSenderOtpJob).to have_been_enqueued.with(global_id(user_with_mobile))
    end

    it 'allows the user to abandon confirmation' do
      get :edit

      expect(response).to render_template(:edit)
    end

    it 'deletes the unconfirmed number once it has been confirmed' do
      user_with_mobile.reload.mobile_confirm

      expect(user_with_mobile.reload.unconfirmed_mobile).to be_nil
    end
  end

  context 'user adds a new mobile number but not mobile 2FA' do
    before do
      sign_in(user)
      put :update, id: user, user: attrs_with_email_2fa
    end

    it_behaves_like 'updating_mobile' do
      let(:test_user) { user }
    end
  end

  # Scenario: User updates both email and number and has both 2FA options
  #   Given I am signed in and editing my profile
  #   When I update both my mobile and email
  #   Then I am asked to confirm both my email and mobile
  #   But OTP confirmation only goes to phone
  context 'user updates both email and mobile number' do
    before do
      sign_in(user)
      reset_email
      put :update, id: user, user: attrs_with_new_email_and_mobile
    end

    it_behaves_like 'updating_both_email_and_mobile' do
      let(:test_user) { user }
    end

    it 'requires the user to confirm both their new email and mobile' do
      expect(flash[:notice]).to eq t('devise.registrations.email_and_mobile_need_confirmation')
      expect(last_email.body).to_not include 'one-time password'
      expect(user.reload.email).to_not eq 'new_email@example.com'
    end
  end

  # Scenario: User deletes phone number when mobile is a 2FA method
  #   Given I am signed in and editing my profile
  #   When I remove my mobile number and check mobile 2fa
  #   Then I see an invalid number message
  context 'user removes mobile number while mobile is a 2FA method' do
    render_views

    it 'displays error message and does not remove mobile' do
      sign_in(user_with_mobile)
      put :update, id: user, user: attrs_with_blank_mobile

      expect(response.body).to have_content invalid_mobile_message
      expect(user_with_mobile.reload.mobile).to be_present
      expect(user.reload.second_factors.pluck(:name)).to eq %w(Email)
    end
  end

  # Scenario: User deletes phone number when mobile is not a 2FA method
  #   Given I am signed in and editing my profile
  #   When I remove my mobile number
  #   Then I see a success message and my number is removed
  context 'user removes mobile number while mobile is not a 2FA method', sms: true do
    before do
      sign_in(user_with_mobile)
      reset_job_queues
      put :update, id: user, user: attrs_with_blank_mobile_and_email_2fa
    end

    it_behaves_like 'updating_profile'

    it 'sets user mobile to nil and does not send any SMS' do
      expect(user_with_mobile.reload.mobile).to be_nil

      expect(SmsSenderNumberChangeJob).to_not have_been_enqueued

      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
    end
  end

  # Scenario: User attempts to delete email
  #   Given I am signed in and editing my profile
  #   When I remove my email
  #   Then I see an error message
  context 'user removes email address' do
    render_views

    it 'displays an error message and does not delete the email' do
      sign_in(user)
      put :update, id: user, user: attrs_with_blank_email

      expect(response.body).to have_content "can't be blank"
      expect(user.reload.email).to be_present
    end
  end

  # Scenario: User adds 2FA via email
  #   Given I am signed in
  #   When I add the Email 2FA method
  #   Then I see 'account has been updated' message
  #   And I don't receive an email
  context 'user adds Email as additional second factor method' do
    before do
      sign_in(user_with_mobile)
      reset_email
      put :update, id: user, user: attrs_with_new_email_2fa
    end

    it_behaves_like 'updating_profile'

    it 'adds email to the user second factors without sending email to user' do
      expect(user_with_mobile.reload.second_factors.pluck(:name).sort).to eq %w(Email Mobile)
      expect(last_email).to be_nil
    end
  end

  # Scenario: User adds 2FA via mobile
  #   Given I am signed in
  #   When I add the Mobile 2FA method
  #   Then I am prompted to confirm my number
  context 'user adds Mobile as additional second factor method' do
    before do
      sign_in(user)
      put :update, id: user, user: attrs_with_both_2fa
    end

    it_behaves_like 'adding_mobile'
  end

  # Scenario: User attempts to disable all 2FA methods
  #   Given I am signed in
  #   When I disable all 2FA methods
  #   Then I am forced to choose at least one option
  context 'user unchecks all second factor methods' do
    render_views

    it 'displays an error message' do
      sign_in(user)
      put :update, id: user, user: attrs_with_no_2fa

      expect(response.body).
        to have_content t('activerecord.errors.models.user.attributes.second_factors.blank')
    end
  end

  # Scenario: User has both 2FA methods and disables Mobile
  #   Given I am signed in
  #   When I disable Mobile without removing my number
  #   Then my Mobile 2FA is removed but my phone number remains
  context 'user unchecks mobile second factor method' do
    before do
      sign_in(user_with_mobile)
      put :update, id: user_with_mobile, user: attrs_with_mobile_and_email_2fa
    end

    it_behaves_like 'updating_profile'

    it 'removes mobile 2FA but leaves mobile' do
      expect(user_with_mobile.reload.second_factors.pluck(:name)).to eq %w(Email)
      expect(user_with_mobile.reload.mobile).to eq '+1 (500) 555-0006'
    end
  end

  # Scenario: User has both 2FA methods and disables Email
  #   Given I am signed in
  #   When I disable Email
  #   Then my Email 2FA is removed but my email remains
  context 'user unchecks email second factor method' do
    before do
      sign_in(user_with_mobile)
      put :update, id: user_with_mobile, user: attrs_with_mobile_and_mobile_2fa
    end

    it_behaves_like 'updating_profile'

    it 'removes email 2FA but leaves email' do
      expect(user_with_mobile.reload.second_factors.pluck(:name)).to eq %w(Mobile)
      expect(user_with_mobile.reload.email).to eq 'mobile@example.com'
    end
  end

  context 'user changes email' do
    before do
      sign_in(user)
      put :update, id: user, user: attrs_with_new_email
    end

    it 'lets user know they need to confirm their new email' do
      expect(response).to redirect_to edit_user_registration_url
      expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
      expect(response).to render_template('devise/mailer/confirmation_instructions')
      expect(user.reload.email).to eq 'old_email@example.com'
    end
  end

  context 'user changes email to an existing email address' do
    it 'lets user know they need to confirm their new email' do
      sign_in(user)
      put :update, id: user, user: attrs_with_new_email.merge(email: user_with_mobile.email)

      expect(response).to redirect_to edit_user_registration_url
      expect(flash[:notice]).to eq t('devise.registrations.email_update_needs_confirmation')
      expect(response).to render_template('user_mailer/signup_with_your_email')
      expect(user.reload.email).to eq 'old_email@example.com'
      expect(last_email.subject).to eq 'Email Confirmation Notification'
    end
  end

  context 'user changes password', email: true do
    before do
      sign_in(user)
      put :update, id: user, user: attrs_with_new_valid_password
    end

    it_behaves_like 'updating_profile'

    it 'changes the password successfully and sends the user an email' do
      expect(user.reload.encrypted_password).to_not eq old_encrypted_password
      expect(response).to render_template('user_mailer/password_changed')
    end
  end

  describe 'EmailNotifier' do
    context 'user changes password', email: true do
      it 'calls EmailNotifier' do
        notifier = instance_double(EmailNotifier)

        expect(EmailNotifier).to receive(:new).with(user).and_return(notifier)
        expect(notifier).to receive(:send_password_changed_email)

        sign_in(user)
        put :update, id: user, user: attrs_with_new_valid_password
      end
    end
  end

  context 'invalid password' do
    render_views

    it 'displays invalid password error' do
      sign_in(user)
      put :update, id: user, user: attrs_with_new_invalid_password

      expect(response.body).to have_content('too short')
      expect(user.reload.encrypted_password).to eq old_encrypted_password
    end
  end

  context 'user updates profile with existing mobile but without current password' do
    render_views

    it 'displays error about blank current password but not about mobile' do
      sign_in(user)
      put(
        :update,
        id: user,
        user: attrs_without_current_password.merge(mobile: user_with_mobile.mobile)
      )

      expect(response.body).to have_content("can't be blank")
      expect(response.body).to_not have_content('has already been taken')
      expect(user.reload.email).to eq 'old_email@example.com'
    end
  end

  context 'user signs up with existing email' do
    it 'sends an email to the existing user' do
      existing_user = create(:user, email: 'existing@example.com')

      mailer = instance_double(ActionMailer::MessageDelivery)
      expect(UserMailer).to receive(:signup_with_your_email).with(existing_user).and_return(mailer)
      expect(mailer).to receive(:deliver_later)

      put :create, user: { email: 'existing@example.com' }
    end
  end

  context 'user updates profile with invalid email and existing mobile', sms: true do
    render_views

    it 'displays error about invalid email' do
      sign_in(user)
      put(
        :update,
        id: user,
        user: attrs_with_both_2fa.merge!(email: 'foo', mobile: user_with_mobile.mobile)
      )

      expect(response.body).to have_content('Please enter a valid email')
      expect(response.body).to_not have_content('has already been taken')
      expect(SmsSenderNumberChangeJob).to_not have_been_enqueued
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user))
      expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
    end
  end

  context 'user updates profile with invalid mobile and existing email' do
    render_views

    it 'displays error about invalid email', email: true do
      sign_in(user)
      put(
        :update,
        id: user,
        user: attrs_with_both_2fa.merge!(email: user_with_mobile.email, mobile: '703')
      )

      expect(flash).to be_empty
      expect(response.body).to have_content('number is invalid')
      expect(response.body).to_not have_content('has already been taken')
      expect(last_email).to be_nil
    end
  end
end
