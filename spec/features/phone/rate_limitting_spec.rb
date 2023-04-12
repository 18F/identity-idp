require 'rails_helper'

describe 'phone rate limitting' do
  let(:phone) { '2025551234' }

  context 'on sign up' do
    let!(:user) { sign_up_and_set_password }

    it_behaves_like 'phone rate limitting', :sms
    it_behaves_like 'phone rate limitting', :voice

    def visit_otp_confirmation(delivery_method)
      select_2fa_option(:phone)
      select_phone_delivery_option(delivery_method)
      fill_in :new_phone_form_phone, with: phone
      click_send_one_time_code
    end
  end

  context 'on add phone' do
    let(:user) { create(:user, :signed_up) }

    it_behaves_like 'phone rate limitting', :sms
    it_behaves_like 'phone rate limitting', :voice

    def visit_otp_confirmation(delivery_method)
      sign_in_live_with_2fa(user)
      within('.sidenav-mobile') do
        click_on t('account.navigation.add_phone_number')
      end
      fill_in :new_phone_form_phone, with: phone
      select_phone_delivery_option(delivery_method)
      click_continue
    end
  end
end
