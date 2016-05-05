require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has unconfirmed_mobile and is two_factor_enabled' do
    it 'only mentions mobile' do
      user = create(:user, :signed_up, unconfirmed_mobile: '5005550999')
      allow(view).to receive(:current_user).and_return(user)
      @user_decorator = UserDecorator.new(user)

      render

      expect(rendered).to have_content 'A one-time passcode has been sent to +1 (500) 555-0999.'
    end
  end

  context 'user has second factor and no unconfirmed email' do
    it 'mentions mobile' do
      user = create(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      @user_decorator = UserDecorator.new(user)

      render

      expect(rendered).to have_content "A one-time passcode has been sent to #{user.mobile}."
    end

    it 'prompts the user to enter an OTP' do
      user = create(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      @user_decorator = UserDecorator.new(user)

      render

      expect(rendered).
        to have_content t('devise.two_factor_authentication.header_text')
    end
  end
end
