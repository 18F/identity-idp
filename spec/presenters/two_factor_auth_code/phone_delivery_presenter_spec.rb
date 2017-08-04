require 'rails_helper'

describe TwoFactorAuthCode::PhoneDeliveryPresenter do
  let(:data) do
    {
      code_value: '123abc',
      totp_enabled: false,
      phone_number: '***-***-5000',
      unconfirmed_phone: false,
      otp_delivery_preference: 'sms',
    }
  end
  let(:view) { ActionController::Base.new.view_context }
  let(:presenter) { TwoFactorAuthCode::PhoneDeliveryPresenter.new(data: data, view: view) }

  it 'is a subclass of GenericDeliveryPresenter' do
    expect(TwoFactorAuthCode::PhoneDeliveryPresenter.superclass).to(
      be(TwoFactorAuthCode::GenericDeliveryPresenter)
    )
  end

  describe '#fallback_links' do
    context 'with totp enabled' do
      before do
        data[:totp_enabled] = true
      end

      context 'voice otp delivery supported' do
        it 'renders an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'renders a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end

      context 'voice otp deliver unsupported' do
        before do
          data[:voice_otp_delivery_unsupported] = true
        end

        it 'renders an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'does not render a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end
    end

    context 'without totp enabled' do
      context 'voice otp delivery supported' do
        it 'does not render an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'renders a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end

      context 'voice otp deliver unsupported' do
        before do
          data[:voice_otp_delivery_unsupported] = true
        end

        it 'does not render an auth app fallback link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.app')
          )
        end

        it 'does not render a voice otp link' do
          expect(presenter.fallback_links.join(' ')).to_not include(
            I18n.t('links.two_factor_authentication.voice')
          )
        end
      end
    end
  end
end
