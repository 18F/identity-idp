require 'rails_helper'

describe 'devise/two_factor_authentication/show.html.slim' do
  context 'user has a mobile' do
    let(:user) { build_stubbed(:user, :signed_up) }

    it 'has a localized heading' do
      render

      expect(rendered).to have_content t('devise.two_factor_authentication.header_text')
    end

    it 'informs the user that an OTP has been sent to their number' do
      allow(view).to receive(:current_user).and_return(user)
      @phone_number = user.decorate.masked_two_factor_phone_number
      render

      expect(rendered).to have_content 'Please enter the code sent to ***-***-1212'
    end

    context 'when @code_value is set' do
      before { @code_value = '12777' }

      it 'pre-populates the form field' do
        render

        expect(rendered).to have_xpath("//input[@value='12777']")
      end
    end
  end
end
