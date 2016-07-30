require 'rails_helper'

describe 'shared/_nav.html.slim' do
  context 'user is signed out' do
    before do
      allow(view).to receive(:signed_in?).and_return(false)
    end

    it 'contains sign in link' do
      render

      expect(rendered).to have_link(t('links.sign_in'), href: new_user_session_path)
    end

    it 'contains sign up link' do
      render

      expect(rendered).to have_link(t('links.sign_up'), href: new_user_start_path)
    end

    it 'does not contain sign out link' do
      render

      expect(rendered).to_not have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
  end

  context 'user is signed in' do
    before do
      @user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(@user)
      allow(view).to receive(:signed_in?).and_return(true)
    end

    it 'contains welcome message' do
      render

      expect(rendered).to have_content "Welcome #{@user.email}"
    end

    it 'contains sign out link' do
      render

      expect(rendered).to have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
  end
end
