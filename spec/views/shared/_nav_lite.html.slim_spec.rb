require 'rails_helper'

describe 'shared/_nav_lite.html.slim' do
  context 'user is signed out' do
    before do
      allow(view).to receive(:signed_in?).and_return(false)
    end

    it 'does not contain sign out link' do
      render

      expect(rendered).to_not have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
  end
end
