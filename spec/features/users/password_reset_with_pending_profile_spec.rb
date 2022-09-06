require 'rails_helper'

feature 'reset password with pending profile' do
  include PersonalKeyHelper

  let(:user) { create(:user, :signed_up) }

  scenario 'password reset email includes warning for pending profile' do
    profile = create(
      :profile,
      deactivation_reason: :gpo_verification_pending,
      pii: { ssn: '666-66-1234', dob: '1920-01-01', phone: '+1 703-555-9999' },
      user: user,
    )
    create(:gpo_confirmation_code, profile: profile)

    trigger_reset_password_and_click_email_link(user.email)

    html_body = ActionMailer::Base.deliveries.last.html_part.body.decoded
    expect(html_body).to include(
      t('user_mailer.reset_password_instructions.gpo_letter_description'),
    )
  end

  scenario 'password reset email does not include warning without pending profile' do
    trigger_reset_password_and_click_email_link(user.email)

    html_body = ActionMailer::Base.deliveries.last.html_part.body.decoded
    expect(html_body).to_not include(
      t('user_mailer.reset_password_instructions.gpo_letter_description'),
    )
  end
end
