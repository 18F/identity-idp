require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has unconfirmed_mobile and is two_factor_enabled' do
    it 'only mentions mobile' do
      allow(view).to receive(:current_user).
        and_return(create(:user, :tfa_confirmed, unconfirmed_mobile: '5005550006'))

      render

      expect(rendered).to have_content 'A one-time passcode has been sent to 5005550006.'
    end
  end

  context 'user has 2 second factors but no unconfirmed email' do
    it 'mentions both email and mobile' do
      allow(view).to receive(:current_user).
        and_return(
          create(
            :user, :signed_up, :both_tfa_confirmed, email: 'foo@bar.com', mobile: '5005550006'
          )
        )

      render

      expect(rendered).
        to have_content 'A one-time passcode has been sent to foo@bar.com and +1 (500) 555-0006.'
    end
  end

  context 'user only has email second factor and no unconfirmed email' do
    it 'mentions email' do
      allow(view).to receive(:current_user).
        and_return(create(:user, :signed_up, email: 'foo@bar.com'))

      render

      expect(rendered).to have_content 'A one-time passcode has been sent to foo@bar.com.'
    end

    it 'prompts the user to enter an OTP' do
      allow(view).to receive(:current_user).and_return(create(:user, :signed_up))

      render

      expect(rendered).
        to have_content t('devise.two_factor_authentication.header_text')
    end
  end

  context 'user only has mobile second factor and no unconfirmed email' do
    it 'mentions mobile' do
      allow(view).to receive(:current_user).and_return(create(:user, :signed_up, :with_mobile))

      render

      expect(rendered).to have_content 'A one-time passcode has been sent to +1 (500) 555-0006.'
    end
  end
end
