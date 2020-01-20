require 'rails_helper'

describe 'Remember device checkbox' do
  context 'when the user signs in and arrives at the 2FA page' do
    it "has a checked 'remember device' box" do
      user = create(:user, :signed_up)
      sign_in_user(user)

      expect(page).
          to have_checked_field t('forms.messages.remember_device')
    end
  end
end
