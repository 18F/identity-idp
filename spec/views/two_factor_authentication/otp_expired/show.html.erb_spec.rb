require 'rails_helper'

RSpec.describe 'two_factor_authentication/otp_expired/show.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.otp_expired'))

    render
  end

  it 'includes link to contact support' do
    render

    expect(rendered).to have_link(
      t('links.contact_support', app_name: APP_NAME),
      href: contact_redirect_path(flow: :two_factor_authentication, step: :otp_expired),
    )
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
    let(:user) { create(:user, :fully_registered, :with_phone) }

    it 'use another phone number option is not on screen' do
      render

      expect(rendered).to_not have_link(
        t('two_factor_authentication.phone_verification.troubleshooting.change_number'),
      )
    end

    it 'can redirect to choose another option' do
      assign(:authentication_options_path, 'foo')

      render

      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: 'foo',
      )
    end
  end

  context 'when a user creates a new account' do
    it 'allows a user to select another phone' do
      assign(:use_another_phone_path, false)

      render

      expect(rendered).to_not have_content(
        t('two_factor_authentication.phone_verification.troubleshooting.change_number'),
      )
    end
  end
end
