require 'rails_helper'

describe 'phone rate limitting' do
  let(:phone) { '2025551234' }

  context 'on sign up' do
    let!(:user) { sign_up_and_set_password }

    context 'as first MFA method' do
      it_behaves_like 'phone rate limitting', :sms
      it_behaves_like 'phone rate limitting', :voice

      def visit_otp_confirmation(delivery_method)
        select_2fa_option(:phone)
        select_phone_delivery_option(delivery_method)
        fill_in :user_phone_form_phone, with: phone
        click_send_security_code
      end
    end

    context 'as second MFA method' do
      it_behaves_like 'phone rate limitting', :sms
      it_behaves_like 'phone rate limitting', :voice

      def visit_otp_confirmation(delivery_method)
        select_2fa_option(:phone)
        select_phone_delivery_option(:sms)
        fill_in :user_phone_form_phone, with: '2025551313'
        click_send_security_code
        fill_in_code_with_last_phone_otp
        click_submit_default

        click_continue

        select_2fa_option(:phone)
        select_phone_delivery_option(delivery_method)
        fill_in :user_phone_form_phone, with: phone
        click_send_security_code
      end
    end
  end

  context 'on sign in' do
    let(:user) { create(:user, :signed_up) }

    it_behaves_like 'phone rate limitting', :sms
    it_behaves_like 'phone rate limitting', :voice

    def visit_otp_confirmation(delivery_method)
      user.phone_configurations.first.update!(
        phone: PhoneFormatter.format(phone),
        delivery_preference: delivery_method,
      )
      sign_in_user(user)
    end
  end

  context 'on add phone' do
    let(:user) { create(:user, :signed_up) }

    it_behaves_like 'phone rate limitting', :sms
    it_behaves_like 'phone rate limitting', :voice

    def visit_otp_confirmation(delivery_method)
      sign_in_live_with_2fa(user)
      click_on t('account.index.phone_add')
      fill_in :user_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_continue
    end
  end
end
