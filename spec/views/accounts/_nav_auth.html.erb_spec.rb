require 'rails_helper'

RSpec.describe 'accounts/_nav_auth.html.erb' do
  include Devise::Test::ControllerHelpers

  before do
    @user = build_stubbed(:user, :with_backup_code)
    allow(view).to receive(:greeting).and_return(@user.email)
    allow(view).to receive(:current_user).and_return(@user)
    render partial: 'accounts/nav_auth'
  end

  it 'contains an account menu whose accessible name includes the user email' do
    menu_label = t('account.navigation.account_menu')

    # The visible email is part of the summary's accessible name (WCAG 2.5.3
    # Label in Name), so no aria-label overrides it; the "Account menu" context
    # is supplied by an sr-only label alongside the visible email.
    expect(rendered).to have_css(
      'details.ads-account-header__menu summary:not([aria-label])',
      text: @user.email,
    )
    expect(rendered).to have_css(
      'details.ads-account-header__menu summary .ads-sr-only',
      text: menu_label,
      visible: :all,
    )
  end

  it 'does not contain link to cancel the auth process' do
    expect(rendered).not_to have_link(t('links.cancel'))
  end

  it 'contains menu button' do
    expect(rendered).to have_css(
      '.ads-account-mobile-menu__summary',
      text: t('account.navigation.menu'),
    )
  end

  it 'contains sign out button inside the account menu' do
    expect(rendered).to have_css(
      ".ads-account-header__menu-panel form.ads-account-header__menu-form[action='#{logout_path}']",
      visible: :all,
    )
    expect(rendered).to have_button(t('links.sign_out'), visible: :all)
  end
end
