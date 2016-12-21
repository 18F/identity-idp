require 'rails_helper'

describe 'users/two_factor_authentication/show.html.slim' do
  context 'user has a phone' do
    let(:user) { build_stubbed(:user, :signed_up) }
    let(:presenter_data) { attributes_for(:generic_otp_presenter) }

    before do
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new
      allow(view).to receive(:reauthn?).and_return(false)
      allow(view).to receive(:current_user).and_return(user)

      otp_data = presenter_data.merge(
        delivery_method: nil,
        phone_number: view.current_user.phone
      )

      @presenter = TwoFactorAuthCode::OtpDeliveryPresenter.new(otp_data)

      render
    end

    it_behaves_like 'an otp form'

    it 'has a localized heading' do
      expect(rendered).to have_content t('headings.choose_otp_delivery')
    end

    it 'allows the user to select OTP delivery method' do
      expect(rendered).to have_content t('devise.two_factor_authentication.otp_method.sms')
      expect(rendered).to have_content t('devise.two_factor_authentication.otp_method.voice')
    end

    it 'informs the user that an OTP will be sent to their number' do
      expect(rendered).to have_content(
        t('devise.two_factor_authentication.choose_otp_delivery_html',
          phone: @presenter.phone_number)
      )
    end
  end
end
