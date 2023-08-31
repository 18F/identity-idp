require 'rails_helper'

RSpec.describe 'accounts/_nav_auth.html.erb' do
  include Devise::Test::ControllerHelpers

  before do
    @user = build_stubbed(:user, :with_backup_code)
    allow(view).to receive(:greeting).and_return(@user.email)
    allow(view).to receive(:current_user).and_return(@user)
  end

  context 'user is signed in' do
    before do
      render partial: 'accounts/nav_auth', locals: { enable_mobile_nav: false }
    end

    it 'contains welcome message' do
      expect(rendered).to have_content "Welcome #{@user.email}", normalize_ws: true
    end

    it 'does not contain link to cancel the auth process' do
      expect(rendered).not_to have_link(t('links.cancel'), href: destroy_user_session_path)
    end

    it 'contains sign out link' do
      expect(rendered).to have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
  end

  context 'mobile nav is enabled' do
    before do
      render partial: 'accounts/nav_auth', locals: { enable_mobile_nav: true }
    end

    it 'contains menu button' do
      expect(rendered).to have_button t('account.navigation.menu')
    end
  end
end
