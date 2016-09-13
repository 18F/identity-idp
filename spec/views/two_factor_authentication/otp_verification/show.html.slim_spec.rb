require 'rails_helper'

describe 'two_factor_authentication/otp_verification/show.html.slim' do
  context 'user has a phone' do
    let(:user) { build_stubbed(:user, :signed_up) }

    it 'has a localized heading' do
      controller.request.path_parameters[:delivery_method] = 'sms'

      render

      expect(rendered).to have_content t('devise.two_factor_authentication.header_text')
    end

    it 'informs the user that an OTP has been sent to their number' do
      allow(view).to receive(:current_user).and_return(user)
      @phone_number = user.decorate.masked_two_factor_phone_number
      controller.request.path_parameters[:delivery_method] = 'sms'

      render

      expect(rendered).to have_content 'Please enter the code sent to ***-***-1212'
    end

    context 'when @code_value is set' do
      it 'pre-populates the form field' do
        @code_value = '12777'
        controller.request.path_parameters[:delivery_method] = 'sms'

        render

        expect(rendered).to have_xpath("//input[@value='12777']")
      end
    end

    context 'when choosing to receive OTP via SMS' do
      it 'has a link to send confirmation with voice' do
        controller.request.path_parameters[:delivery_method] = 'sms'
        @delivery_method = 'sms'

        render

        expect(rendered).to have_link(
          t('links.phone_confirmation.fallback_to_voice.link_text'),
          href: otp_send_path(otp_delivery_selection_form: { otp_method: 'voice' })
        )
      end
    end

    context 'when choosing to receive OTP via voice' do
      it 'has a link to send confirmation as SMS' do
        controller.request.path_parameters[:delivery_method] = 'voice'
        @delivery_method = 'voice'

        render

        expect(rendered).to have_link(
          t('links.phone_confirmation.fallback_to_sms.link_text'),
          href: otp_send_path(otp_delivery_selection_form: { otp_method: 'sms' })
        )
      end
    end
  end
end
