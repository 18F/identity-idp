require 'rails_helper'

describe TwoFactorAuthCode::PhoneDeliveryPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper

  let(:view) { ActionController::Base.new.view_context }
  let(:data) do
    {
      confirmation_for_add_phone: false,
      phone_number: '5555559876',
      code_value: '999999',
      otp_delivery_preference: 'sms',
      unconfirmed_phone: true,
      totp_enabled: false,
      personal_key_unavailable: true,
      reauthn: false,
    }
  end
  let(:presenter) do
    TwoFactorAuthCode::PhoneDeliveryPresenter.new(
      data: data,
      view: view,
      service_provider: nil,
    )
  end

  it 'is a subclass of GenericDeliveryPresenter' do
    expect(TwoFactorAuthCode::PhoneDeliveryPresenter.superclass).to(
      be(TwoFactorAuthCode::GenericDeliveryPresenter),
    )
  end

  describe '#cancel_link' do
    it 'returns the sign out path during authentication' do
      expect(presenter.cancel_link).to eq sign_out_path
    end

    it 'returns the account path during reauthn' do
      data[:reauthn] = true
      expect(presenter.cancel_link).to eq account_path
    end

    it 'returns the account path during phone change confirmation' do
      data[:confirmation_for_add_phone] = true
      expect(presenter.cancel_link).to eq account_path
    end
  end

  describe '#phone_number_message' do
    it 'specifies when the code will expire' do
      text = t(
        'instructions.mfa.sms.number_message_html',
        number: ActionController::Base.helpers.content_tag(:strong, data[:phone_number]),
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
      )
      expect(presenter.phone_number_message).to eq text
    end
  end

  describe '#landline_warning' do
    let(:landline_html) do
      t(
        'two_factor_authentication.otp_delivery_preference.landline_warning_html',
        phone_setup_path: link_to(
          presenter.phone_call_text,
          phone_setup_path(otp_delivery_preference: 'voice'),
        ),
      )
    end

    it 'returns translated landline warning html' do
      expect(presenter.landline_warning).to eq landline_html
    end
  end

  describe '#phone_call_text' do
    let(:phone_call) { t('two_factor_authentication.otp_delivery_preference.phone_call') }

    it 'returns translation for word phone call' do
      expect(presenter.phone_call_text).to eq phone_call
    end
  end

  def account_reset_cancel_link(account_reset_token)
    I18n.t(
      'two_factor_authentication.account_reset.pending_html', cancel_link:
      view.link_to(
        t('two_factor_authentication.account_reset.cancel_link'),
        account_reset_cancel_url(token: account_reset_token),
      )
    )
  end

  def account_reset_delete_account_link
    I18n.t(
      'two_factor_authentication.account_reset.text_html', link:
      view.link_to(
        t('two_factor_authentication.account_reset.link'),
        account_reset_request_path(locale: LinkLocaleResolver.locale),
      )
    )
  end
end
