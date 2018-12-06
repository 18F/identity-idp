require 'rails_helper'

describe TwoFactorAuthCode::Totpable do
  describe '#auth_app_fallback_link' do
    context 'when totp option is not enabled' do
      let(:presenter) do
        TwoFactorAuthCode::PhoneDeliveryPresenter.new(attributes_for(:generic_otp_presenter))
      end

      it 'returns a single period to properly format fallback options' do
        expect(presenter.auth_app_fallback_link).to eq('.')
      end
    end

    context 'when totp option is enabled' do
      let(:presenter) do
        data = attributes_for(:generic_otp_presenter)
        data[:totp_enabled] = true
        TwoFactorAuthCode::PhoneDeliveryPresenter.new(data)
      end

      it 'returns a link to use an authenticator app' do
        actual = presenter.auth_app_fallback_link
        link = '<a href="/login/two_factor/authenticator">authentication app</a>'

        expect(actual).to eq(
          t('links.phone_confirmation.auth_app_fallback_html', link: link)
        )
      end
    end
  end
end
