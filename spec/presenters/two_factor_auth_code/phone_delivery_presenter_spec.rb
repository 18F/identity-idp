require 'rails_helper'

describe TwoFactorAuthCode::PhoneDeliveryPresenter do
  include Rails.application.routes.url_helpers

  let(:view) { ActionController::Base.new.view_context }
  let(:data) do
    {
      confirmation_for_phone_change: false,
      phone_number: '5555559876',
      code_value: '999999',
      otp_delivery_preference: 'sms',
      reenter_phone_number_path: '/manage/phone',
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
      data[:confirmation_for_phone_change] = true
      expect(presenter.cancel_link).to eq account_path
    end
  end

  describe '#phone_number_message' do
    it 'specifies when the code will expire' do
      text = t(
        'instructions.mfa.sms.number_message_html',
        number: "<strong>#{data[:phone_number]}</strong>",
        expiration: Figaro.env.otp_valid_for,
      )
      expect(presenter.phone_number_message).to eq text
    end
  end

  def account_reset_cancel_link(account_reset_token)
    I18n.t('two_factor_authentication.account_reset.pending_html', cancel_link:
      view.link_to(t('two_factor_authentication.account_reset.cancel_link'),
                   account_reset_cancel_url(token: account_reset_token)))
  end

  def account_reset_delete_account_link
    I18n.t('two_factor_authentication.account_reset.text_html', link:
      view.link_to(t('two_factor_authentication.account_reset.link'),
                   account_reset_request_path(locale: LinkLocaleResolver.locale)))
  end
end
