require 'rails_helper'

describe 'phone otp confirmation' do
  let(:phone) { '2025551234' }
  let(:formatted_phone) { PhoneFormatter.format(phone) }

  context 'on sign up as first MFA' do
    let!(:user) { sign_up_and_set_password }

    it_behaves_like 'phone otp confirmation', :sms
    it_behaves_like 'phone otp confirmation', :voice

    context 'with an international phone number' do
      let(:phone) { '+81543543643' }
      it_behaves_like 'phone otp confirmation', :sms
    end

    def visit_otp_confirmation(delivery_method)
      select_2fa_option(:phone)
      fill_in :user_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_send_security_code
    end

    def expect_successful_otp_confirmation(delivery_method)
      select_2fa_option(:backup_code)
      click_continue

      expect(page).to have_current_path(account_path)
      expect(phone_configuration.confirmed_at).to_not be_nil
      expect(phone_configuration.delivery_preference).to eq(delivery_method.to_s)
    end

    def expect_failed_otp_confirmation(_delivery_method)
      visit account_path

      expect(current_path).to eq(two_factor_options_path)
      expect(phone_configuration).to be_nil
    end
  end

  context 'on sign up as second MFA method' do
    let!(:user) { sign_up_and_set_password }

    it_behaves_like 'phone otp confirmation', :sms
    it_behaves_like 'phone otp confirmation', :voice

    context 'with an international phone number' do
      let(:phone) { '+81543543643' }
      it_behaves_like 'phone otp confirmation', :sms
    end

    def visit_otp_confirmation(delivery_method)
      select_2fa_option(:phone)
      fill_in :user_phone_form_phone, with: '2025551313'
      select_phone_delivery_option(:sms)
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      click_continue

      select_2fa_option(:phone)
      fill_in :user_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_send_security_code
    end

    def expect_successful_otp_confirmation(delivery_method)
      expect(page).to have_current_path(account_path)
      expect(phone_configuration.confirmed_at).to_not be_nil
      expect(phone_configuration.delivery_preference.to_s).to eq(delivery_method.to_s)
    end

    def expect_failed_otp_confirmation(_delivery_method)
      visit account_path

      expect(current_path).to eq(two_factor_options_path)
      expect(phone_configuration).to be_nil
    end
  end

  context 'on sign in' do
    let(:user) { create(:user, :signed_up) }
    let(:phone) { user.phone_configurations.first.phone }

    it_behaves_like 'phone otp confirmation', :sms
    it_behaves_like 'phone otp confirmation', :voice

    context 'with an international phone number' do
      before do
        user.phone_configurations.first.update!(phone: formatted_phone)
      end

      let(:phone) { '+81543543643' }
      it_behaves_like 'phone otp confirmation', :sms
    end

    def visit_otp_confirmation(delivery_method)
      user.phone_configurations.first.update!(delivery_preference: delivery_method)
      sign_in_user(user)
    end

    def expect_successful_otp_confirmation(_delivery_method)
      expect(page).to have_current_path(account_path)
    end

    def expect_failed_otp_confirmation(delivery_method)
      visit account_path

      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: delivery_method))
    end
  end

  context 'add phone' do
    let(:user) { create(:user, :signed_up) }

    it_behaves_like 'phone otp confirmation', :sms
    it_behaves_like 'phone otp confirmation', :voice

    context 'with an international phone number' do
      let(:phone) { '+81543543643' }
      it_behaves_like 'phone otp confirmation', :sms
    end

    def visit_otp_confirmation(delivery_method)
      sign_in_live_with_2fa(user)
      click_on t('account.index.phone_add')
      fill_in :user_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_continue
    end

    def expect_successful_otp_confirmation(delivery_method)
      expect(phone_configuration.confirmed_at).to_not be_nil
      expect(phone_configuration.delivery_preference).to eq(delivery_method.to_s)
    end

    def expect_failed_otp_confirmation(_delivery_method)
      expect(phone_configuration).to be_nil
    end
  end

  def phone_configuration
    user.reload.phone_configurations.detect do |phone_configuration|
      phone_configuration.phone == formatted_phone
    end
  end
end
