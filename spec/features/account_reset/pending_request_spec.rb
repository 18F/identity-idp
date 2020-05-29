require 'rails_helper'

feature 'Pending account reset request sign in' do
  it 'gives the option to cancel the request on sign in' do
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('999')

    user = create(:user, :signed_up)
    sign_in_user(user)
    click_link t('two_factor_authentication.login_options_link_text')
    click_link t('two_factor_authentication.account_reset.link')
    click_button t('account_reset.request.yes_continue')

    Capybara.reset_session!

    sign_in_user(user)

    expect(page).to have_content(t('account_reset.pending.header'))

    click_on t('account_reset.pending.click_here')

    expect(page).to have_current_path(
      login_two_factor_path(otp_delivery_preference: :sms, reauthn: false),
    )

    # Signing in after cancelling should not show a pending request and go string to MFA
    Capybara.reset_session!
    sign_in_user(user)
    expect(page).to have_current_path(
      login_two_factor_path(otp_delivery_preference: :sms, reauthn: false),
    )
  end
end
