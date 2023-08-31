require 'rails_helper'

RSpec.describe 'Remember device checkbox' do
  include SamlAuthHelper

  context 'when the user signs in and arrives at the 2FA page' do
    it "has a checked 'remember device' box" do
      user = create(:user, :fully_registered)
      sign_in_user(user)

      expect(page).
        to have_checked_field t('forms.messages.remember_device')
    end
  end
  context 'when signing in from an SP when the SP is AAL2' do
    before do
      ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:server').update!(
        default_aal: 2,
      )
    end

    it 'does not have remember device checked' do
      user = create(:user, :fully_registered)
      visit_idp_from_sp_with_ial1(:oidc)
      fill_in_credentials_and_submit(user.email, user.password)
      expect(page).to_not have_checked_field t('forms.messages.remember_device')
    end
  end

  context 'when signing in from an SP that has not opted out of remember device' do
    it 'does have remember device checked' do
      user = create(:user, :fully_registered)
      visit_idp_from_sp_with_ial1(:oidc)
      fill_in_credentials_and_submit(user.email, user.password)
      expect(page).to have_checked_field t('forms.messages.remember_device')
    end
  end
end
