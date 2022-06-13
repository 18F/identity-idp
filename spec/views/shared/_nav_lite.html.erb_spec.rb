require 'rails_helper'

describe 'shared/_nav_lite.html.erb' do
  context 'user is signed out' do
    before do
      allow(view).to receive(:signed_in?).and_return(false)
    end

    it 'does not contain sign out link' do
      render

      expect(rendered).to_not have_button(t('links.sign_out'))
    end
  end
end
