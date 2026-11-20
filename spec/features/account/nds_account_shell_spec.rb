require 'rails_helper'

RSpec.feature 'NDS account shell' do
  let(:user) { create(:user, :fully_registered, :with_multiple_emails) }

  before do
    allow(IdentityConfig.store).to receive(:ui_test_bucket_params_enabled).and_return(true)
    sign_in_and_2fa_user(user)
    visit account_path(ui_test_bucket: 'nds')
  end

  def current_nav_item
    find('.account-shell__nav .account-nav__link--current').text.squish
  end

  scenario 'the account page renders in the shell with the signed-in header' do
    expect(page).to have_css('link[href*="nds_application"]', visible: :all)
    expect(page).to have_css('header.account-header')
    expect(page).to have_css(
      '.account-header__menu-email',
      text: user.last_sign_in_email_address.email,
    )
    expect(page).to have_css('.account-shell main#main-content')
    expect(page).not_to have_css('.sidenav')
    expect(current_nav_item).to eq(t('nds.account_nav.account'))
  end

  scenario 'the side navigation reaches every tab and marks it as current' do
    within('.account-shell__nav') { click_link t('nds.account_nav.security') }
    expect(page).to have_current_path(account_two_factor_authentication_path)
    expect(current_nav_item).to eq(t('nds.account_nav.security'))

    within('.account-shell__nav') { click_link t('account.navigation.history') }
    expect(page).to have_current_path(account_history_path)
    expect(current_nav_item).to eq(t('account.navigation.history'))

    within('.account-shell__nav') { click_link t('nds.account_nav.home') }
    expect(page).to have_current_path(account_connected_services_path)
    expect(current_nav_item).to eq(t('nds.account_nav.home'))

    within('.account-shell__nav') { click_link t('nds.account_nav.account') }
    expect(page).to have_current_path(account_path)
    expect(current_nav_item).to eq(t('nds.account_nav.account'))
  end

  scenario 'device details render in the shell with History current' do
    device = create(:device, user:)
    create(:event, user:, device:, event_type: :sign_in_after_2fa)

    visit account_events_path(id: device.id)

    expect(page).to have_css('.account-shell main', text: device.decorate.nice_name)
    expect(current_nav_item).to eq(t('account.navigation.history'))
  end

  scenario 'forms in the shell still post, and the flash shows in the shell' do
    email = user.email_addresses.last
    visit manage_email_confirm_delete_path(id: email.id)
    click_button t('forms.email.buttons.delete')

    expect(page).to have_current_path(account_path)
    expect(page).to have_css('.account-shell__flash', text: t('email_addresses.delete.success'))
    expect(page).not_to have_content(email.email)
  end

  scenario 'the email menu signs the user out' do
    within('.account-header__menu') do
      find_button(t('links.sign_out'), visible: :all).click
    end

    expect(page).to have_current_path(root_path, ignore_query: true)
    visit account_path
    expect(page).to have_current_path(new_user_session_path, ignore_query: true)
  end

  scenario 'the default bucket keeps the legacy account layout' do
    visit account_path(ui_test_bucket: 'legacy')

    expect(page).to have_css('.sidenav')
    expect(page).not_to have_css('.account-shell')
    expect(page).not_to have_css('link[href*="nds_application"]', visible: :all)
  end
end
