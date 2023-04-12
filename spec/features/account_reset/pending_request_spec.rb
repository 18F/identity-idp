require 'rails_helper'

feature 'Pending account reset request sign in' do
  it 'gives the option to cancel the request on sign in' do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)

    user = create(:user, :signed_up)
    sign_in_user(user)
    click_link t('two_factor_authentication.login_options_link_text')
    click_link t('two_factor_authentication.account_reset.link')
    expect(page).
      to have_content strip_tags(
        t('account_reset.recovery_options.try_method_again'),
      )
    click_link t('account_reset.request.yes_continue')
    expect(page).
      to have_content strip_tags(
        t('account_reset.request.delete_account'),
      )
    click_button t('account_reset.request.yes_continue')

    Capybara.reset_session!

    sign_in_user(user)
    expect(page).to have_content(t('account_reset.pending.header'))

    click_on t('account_reset.pending.cancel_request')
    expect(page).to have_current_path(account_reset_pending_confirm_path)

    click_on t('links.go_back')
    expect(page).to have_content(t('account_reset.pending.header'))

    click_on t('account_reset.pending.cancel_request')
    click_on t('forms.buttons.continue')
    expect(page).to have_content(t('account_reset.pending.cancelled'))

    click_on t('links.continue_sign_in')
    expect(page).to have_content(t('two_factor_authentication.header_text'))
  end
end
