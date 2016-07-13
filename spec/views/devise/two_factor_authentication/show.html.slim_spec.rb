require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has unconfirmed_mobile' do
    it 'sends OTP to unconfirmed mobile' do
      user = build_stubbed(:user, unconfirmed_mobile: '+1 (500) 555-0999')
      allow(view).to receive(:current_user).and_return(user)
      @phone_number = UserDecorator.new(user).masked_two_factor_phone_number

      render

      expect(rendered).
        to have_content 'A one-time passcode has been sent to ***-***-0999'
    end
  end

  context 'user has a confirmed mobile' do
    it 'sends OTP to mobile and prompts to enter the OTP' do
      user = build_stubbed(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      @phone_number = UserDecorator.new(user).masked_two_factor_phone_number

      render

      expect(rendered).
        to have_content 'A one-time passcode has been sent to ***-***-1212'

      expect(rendered).
        to have_content t('devise.two_factor_authentication.header_text')
    end
  end

  it 'displays how long the OTP is valid for' do
    user = build_stubbed(:user, :signed_up)
    allow(view).to receive(:current_user).and_return(user)

    render

    expect(rendered).to have_content distance_of_time_in_words(Devise.direct_otp_valid_for)
  end
end
