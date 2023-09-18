require 'rails_helper'

RSpec.feature 'Visitor signs up with email address' do
  scenario 'visitor can sign up with valid email address' do
    email = 'test@example.com'
    sign_up_with(email)

    expect(page).to have_content t('notices.signed_up_but_unconfirmed.first_paragraph_start')
    expect(page).to have_content t('notices.signed_up_but_unconfirmed.first_paragraph_end')
    expect(page).to have_content email
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)
  end

  scenario 'visitor cannot sign up with invalid email address' do
    sign_up_with('bogus')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'visitor cannot sign up with email with invalid domain name' do
    invalid_addresses = [
      'foo@bar.com',
      'foo@example.com',
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      sign_up_with(email)
      expect(page).to have_content(t('valid_email.validations.email.invalid'))
    end
  end

  scenario 'visitor cannot sign up with empty email address', js: true do
    sign_up_with('')

    # NOTE: If JS is disabled, the browser's built-in frontend validation for the `required`
    # attribute will prevent the form from being submitted, and the user will see the browser's
    # default validation error message.
    expect(page).to have_content t('simple_form.required.text')
  end

  context 'user signs up and sets password, tries to sign up again' do
    scenario 'sends email saying someone tried to sign up with their email address' do
      user = create(:user)

      expect { sign_up_with(user.email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(last_email.html_part.body).to have_content(
        t('user_mailer.signup_with_your_email.intro_html', app_name_html: APP_NAME),
      )
    end
  end

  scenario 'taken to profile page after sign up flow complete' do
    visit sign_up_email_path
    sign_up_and_2fa_ial1_user

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(1)
    expect(current_path).to eq account_path
  end

  it 'returns a bad request if the email contains invalid bytes' do
    suppress_output do
      sign_up_with("test@\xFFbar\xF8.com")
      expect(page).to have_content 'Bad request'
    end
  end

  it 'rate limits sending confirmations after limit is reached' do
    email = 'test@test.com'
    sign_up_with(email)

    starting_count = unread_emails_for(email).size
    max_attempts = IdentityConfig.store.reg_unconfirmed_email_max_attempts
    (max_attempts - 1 - starting_count).times do |i|
      sign_up_with(email)
      expect(unread_emails_for(email).size).to eq(starting_count + i + 1)
    end

    expect(unread_emails_for(email).size).to eq(starting_count + max_attempts - 1 - starting_count)
    sign_up_with(email)
    expect(unread_emails_for(email).size).to eq(starting_count + max_attempts - 1 - starting_count)
  end
end
