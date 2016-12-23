require 'rails_helper'

describe 'shared/_nav_auth.html.slim' do
  context 'user is signed in' do
    before do
      @user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(@user)
      render
    end

    it 'contains welcome message' do
      expect(rendered).to have_content "Welcome #{@user.email}"
    end

    it 'contains link to my account' do
      expect(rendered).to have_link(t('shared.nav_auth.my_account'), href: profile_path)
    end

    it 'does not contain link to cancel the auth process' do
      expect(rendered).not_to have_link(t('links.cancel'), href: destroy_user_session_path)
    end

    it 'contains sign out link' do
      expect(rendered).to have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
  end
end
