require 'rails_helper'

feature 'adding email address' do
  let(:email) { 'test@test.com' }

  it 'allows the user to add an email and confirm with an active session' do
    allow(UserMailer).to receive(:email_added).and_call_original
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    visit account_path
    expect(page).to have_content("#{email}   #{t('email_addresses.unconfirmed')}")

    click_on_link_in_confirmation_email

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(t('devise.confirmations.confirmed'))
    expect(page).to_not have_content("#{email} #{t('email_addresses.unconfirmed')}")
    expect(UserMailer).to have_received(:email_added).twice
  end

  it 'allows the user to add an email and confirm without an active session' do
    allow(UserMailer).to receive(:email_added).and_call_original
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    Capybara.reset_session!

    click_on_link_in_confirmation_email
    expect(page).to have_current_path(root_path)
    expect(page).to have_content(t('devise.confirmations.confirmed_but_sign_in'))
    expect(UserMailer).to have_received(:email_added).twice
  end

  it 'notifies user they are already confirmed without an active session' do
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    Capybara.reset_session!

    email_to_click_on = last_email_sent
    click_on_link_in_confirmation_email(email_to_click_on)
    click_on_link_in_confirmation_email(email_to_click_on)

    expect(page).to have_current_path(root_path)
    action = t('devise.confirmations.sign_in')
    expect(page).to have_content(t('devise.confirmations.already_confirmed', action: action))
  end

  it 'notifies user they are already confirmed with an active session' do
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    email_to_click_on = last_email_sent
    click_on_link_in_confirmation_email(email_to_click_on)
    click_on_link_in_confirmation_email(email_to_click_on)

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(t('devise.confirmations.already_confirmed', action: nil).strip)
  end

  it 'notifies user they are already confirmed on another account after clicking on link' do
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    email_to_click_on = last_email_sent
    create(:user, :signed_up, email: email)
    click_on_link_in_confirmation_email(email_to_click_on)

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(
      t('devise.confirmations.confirmed_but_remove_from_other_account', app_name: APP_NAME),
    )
  end

  it 'notifies user they are already confirmed on another account via email' do
    create(:user, :signed_up, email: email)

    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user, false)

    expect(last_email_sent.default_part_body.to_s).to have_content(
      t('user_mailer.add_email_associated_with_another_account.intro_html', app_name: APP_NAME),
    )
  end

  it 'routes to root with a bad confirmation token' do
    visit add_email_confirmation_url(confirmation_token: 'foo')

    expect(page).to have_current_path(root_path)
    expect(page).to have_content(t('errors.messages.confirmation_invalid_token'))
  end

  it 'routes to root with a blank confirmation token' do
    visit add_email_confirmation_url(confirmation_token: '')

    expect(page).to have_current_path(root_path)
    expect(page).to have_content(t('errors.messages.confirmation_invalid_token'))
  end

  it 'routes to root with a nil confirmation token and an email address with a nil token' do
    EmailAddress.create(user_id: 1, email: 'foo@bar.gov')
    visit add_email_confirmation_url

    expect(page).to have_current_path(root_path)
    expect(page).to have_content(t('errors.messages.confirmation_invalid_token'))
  end

  it 'does not show add email button when max emails is reached' do
    allow(IdentityConfig.store).to receive(:max_emails_per_account).and_return(1)
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)

    visit account_path
    expect(page).to_not have_link("+ #{t('account.index.email_add')}", href: add_email_path)
  end

  it 'does not allow the user to add an email when max emails is reached' do
    allow(IdentityConfig.store).to receive(:max_emails_per_account).and_return(1)
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)

    visit add_email_path
    expect(page).to have_current_path(account_path)
  end

  it 'stays on form with bad email' do
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)
    visit account_path
    click_link "+ #{t('account.index.email_add')}"

    expect(page).to have_current_path(add_email_path)

    fill_in t('forms.registration.labels.email'), with: 'foo'
    click_button t('forms.buttons.submit.default')

    expect(page).to have_current_path(add_email_path)
  end

  it 'stays on form and gives an error message when adding an email already on the account' do
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)
    visit account_path
    click_link "+ #{t('account.index.email_add')}"

    expect(page).to have_current_path(add_email_path)

    fill_in t('forms.registration.labels.email'), with: user.email_addresses.first.email
    click_button t('forms.buttons.submit.default')

    expect(page).to have_current_path(add_email_path)
    expect(page).to have_content(I18n.t('email_addresses.add.duplicate'))
  end

  it 'does not show verify screen without an email in session from add email' do
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)
    visit add_email_verify_email_path

    expect(page).to have_current_path(add_email_path)
  end

  it 'allows user to resend add email link' do
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    expect(UserMailer).to receive(:add_email).
      with(user, anything, anything).and_call_original
    click_button t('links.resend')
  end

  it 'invalidates the confirmation email/token after 24 hours' do
    user = create(:user, :signed_up)
    sign_in_user_and_add_email(user)

    Capybara.reset_session!

    travel_to(25.hours.from_now) do
      click_on_link_in_confirmation_email
      expect(page).to have_current_path(root_path)
      expect(page).to_not have_content(t('devise.confirmations.confirmed_but_sign_in'))
    end
  end

  it 'does not raise a 500 if user submits in rapid succession violating a db constraint' do
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)

    visit account_path
    click_link "+ #{t('account.index.email_add')}"

    fake_email = instance_double(EmailAddress)
    expect(fake_email).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
    expect(fake_email).to receive(:confirmation_token=)
    expect(fake_email).to receive(:confirmation_sent_at=)
    expect(EmailAddress).to receive(:new).and_return(fake_email)

    fill_in t('forms.registration.labels.email'), with: email
    click_button t('forms.buttons.submit.default')

    expect(page).to have_current_path(add_email_path)
    expect(page).to have_content(t('email_addresses.add.duplicate'))
  end

  def sign_in_user_and_add_email(user, add_email = true)
    sign_in_and_2fa_user(user)

    visit account_path
    click_link "+ #{t('account.index.email_add')}"

    expect(page).to have_current_path(add_email_path)

    if add_email
      expect(UserMailer).to receive(:add_email).
        with(user, anything, anything).and_call_original
    else
      expect(UserMailer).to receive(:add_email_associated_with_another_account).
        with(email).and_call_original
    end

    fill_in t('forms.registration.labels.email'), with: email
    click_button t('forms.buttons.submit.default')

    expect(page).to have_current_path(add_email_verify_email_path)
    expect(page).to have_content email
  end

  def click_on_link_in_confirmation_email(email_to_click_on = last_email_sent)
    set_current_email(email_to_click_on)

    click_email_link_matching(%r{add/email/confirm\?confirmation_token})
  end
end
