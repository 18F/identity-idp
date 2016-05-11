require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has unconfirmed_mobile' do
    it 'sends OTP to unconfirmed mobile' do
      user = build_stubbed(:user, unconfirmed_mobile: '5005550999')
      allow(view).to receive(:current_user).and_return(user)

      render

      expect(rendered).
        to have_content "A one-time passcode has been sent to #{user.unconfirmed_mobile}"
    end
  end

  context 'user has a confirmed mobile' do
    it 'sends OTP to mobile' do
      user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)

      render

      expect(rendered).
        to have_content "A one-time passcode has been sent to #{user.mobile}"
    end

    it 'prompts the user to enter an OTP' do
      allow(view).to receive(:current_user).and_return(create(:user, :signed_up))

      render

      expect(rendered).
        to have_content t('devise.two_factor_authentication.header_text')
    end
  end
end
