require 'rails_helper'

describe 'two_factor_authentication/otp_expired/show.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.otp_expired'))

    render
  end

  context 'when a user selects sms as their otp delivery preference' do
    let(:otp_delivery_preference) { 'sms' }
    it 'resends the code via sms' do
      render

      resend_path = otp_send_path(
        otp_delivery_selection_form: {
          otp_delivery_preference: @otp_delivery_preference,
          resend: true,
        },
      )

      expect(rendered).to have_link(
        t('links.two_factor_authentication.try_again'),
        href: resend_path,
      )
    end
  end

  context 'when a user selects phone as their otp delivery preference' do
    let(:otp_delivery_preference) { 'phone' }
    it 'resends the code via phone' do
      render

      resend_path = otp_send_path(
        otp_delivery_selection_form: {
          otp_delivery_preference: @otp_delivery_preference,
          resend: true,
        },
      )

      expect(rendered).to have_link(
        t('links.two_factor_authentication.try_again'),
        href: resend_path,
      )
    end
  end

  context 'if a user is signing in to an existing account' do
    let(:user) { create(:user, :signed_up, :with_phone, :with_auth_app) }

    it 'use another phone number option is not on screen' do
      render

      expect(rendered).to_not have_link(
        t('two_factor_authentication.phone_verification.troubleshooting.change_number'),
      )
    end

    it 'can redirect to choose another option' do
      render

      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text')
      )
    end
  end
end
