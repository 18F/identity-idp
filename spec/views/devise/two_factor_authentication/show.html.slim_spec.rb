require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has unconfirmed_mobile and is two_factor_enabled' do
    it 'only mentions mobile' do
      allow(view).to receive(:current_user).
        and_return(create(:user, :tfa_confirmed, unconfirmed_mobile: '5005550999'))

      render

      expect(rendered).to have_content 'A one-time passcode has been sent to +1 (500) 555-0999.'
    end
  end

  context 'user has second factor and no unconfirmed email' do
    it 'mentions mobile' do
      allow(view).to receive(:current_user).
        and_return(create(:user, :signed_up, :with_mobile, mobile: '5005550777'))

      render

      expect(rendered).to have_content 'A one-time passcode has been sent to +1 (500) 555-0777.'
    end
  end
end
