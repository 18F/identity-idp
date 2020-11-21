require 'rails_helper'

describe 'phone rate limitting' do
  let(:phone) { '2025551234' }

  context 'on sign up' do
    let!(:user) { sign_up_and_set_password }

    it_behaves_like 'phone rate limitting', :sms
    # Restore this line when voice confirmation is re-enabled
    # it_behaves_like 'phone rate limitting', :voice

    def visit_otp_confirmation(delivery_method)
      select_2fa_option(:phone)
      # Restore this line when voice confirmation is re-enabled
      # select_phone_delivery_option(delivery_method)
      fill_in :new_phone_form_phone, with: phone
      click_send_security_code
    end
  end

  context 'on add phone' do
    let(:user) { create(:user, :signed_up) }

    it_behaves_like 'phone rate limitting', :sms
    # Restore this line when voice confirmation is re-enabled
    # it_behaves_like 'phone rate limitting', :voice

    def visit_otp_confirmation(delivery_method)
      sign_in_live_with_2fa(user)
      click_on "+ #{t('account.index.phone_add')}"
      fill_in :new_phone_form_phone, with: phone
      # Restore this line when voice confirmation is re-enabled
      # select_phone_delivery_option(delivery_method)
      click_continue
    end
  end
end
