require 'rails_helper'

describe 'phone otp confirmation' do
  let(:phone) { '2025551234' }
  let(:formatted_phone) { PhoneFormatter.format(phone) }

  context 'on sign up' do
    let!(:user) { sign_up_and_set_password }

    it_behaves_like 'phone otp confirmation', :sms
    it_behaves_like 'phone otp confirmation', :voice

    def visit_otp_confirmation(delivery_method)
      select_2fa_option(:phone)
      fill_in :new_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_send_security_code
    end

    def expect_successful_otp_confirmation(delivery_method)
      expect(page).to have_content(t('notices.phone_confirmed'))

      expect(page).to have_current_path(account_path)
      expect(phone_configuration.confirmed_at).to_not be_nil
      expect(phone_configuration.delivery_preference).to eq(delivery_method.to_s)
    end

    def expect_failed_otp_confirmation(_delivery_method)
      visit account_path

      expect(current_path).to eq(authentication_methods_setup_path)
      expect(phone_configuration).to be_nil
    end
  end

  context 'on sign in' do
    let(:user) { create(:user, :signed_up) }
    let(:phone) { user.phone_configurations.first.phone }

    it_behaves_like 'phone otp confirmation', :sms
    it_behaves_like 'phone otp confirmation', :voice

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

    def visit_otp_confirmation(delivery_method)
      sign_in_live_with_2fa(user)
      within('.sidenav') do
        click_on t('account.navigation.add_phone_number')
      end
      fill_in :new_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_continue
    end

    def expect_successful_otp_confirmation(delivery_method)
      expect(page).to have_content(t('notices.phone_confirmed'))
      expect(page).to have_current_path(account_path)
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
