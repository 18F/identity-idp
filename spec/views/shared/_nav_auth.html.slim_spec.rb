require 'rails_helper'

describe 'shared/_nav_auth.html.slim' do
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
