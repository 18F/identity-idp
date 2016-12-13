require 'rails_helper'

describe 'users/emails/edit.html.slim' do
  context 'user is not TOTP enabled' do
    before do
      user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      @update_user_email_form = UpdateUserEmailForm.new(user)
    end

    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.edit_info.email'))

      render
    end

    it 'sets form autocomplete to off' do
      render

      expect(rendered).to have_xpath("//form[@autocomplete='off']")
    end
  end
end
