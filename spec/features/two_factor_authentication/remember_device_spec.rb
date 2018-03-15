require 'rails_helper'

feature 'Remembering a 2FA device' do
  before do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    allow(SmsOtpSenderJob).to receive(:perform_now)
  end

  let(:user) { user_with_2fa }

  context 'sms or voice' do
    scenario 'choosing remember device does not require 2fa on sign in' do
      sign_in_after_remembering_device

      expect(current_path).to eq(account_path)
    end

    scenario 'after remember this device expiration passes 2fa required on sign in' do
      sign_in_after_remembering_device(user)
      first(:link, t('links.sign_out')).click

      Timecop.travel Figaro.env.remember_device_expiration_days.to_i.days.from_now do
        sign_in_before_2fa(user)

        expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
      end
    end

    scenario 'after changing phone number 2fa is required on sign in' do
      sign_in_after_remembering_device(user) do
        visit manage_phone_path
        fill_in 'user_phone_form_phone', with: '5551234567'
        click_button t('forms.buttons.submit.confirm_change')
        click_submit_default
      end

      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
    end
  end

  context 'a user signs in after a different user has remembered a device' do
    scenario 'the second user must 2FA' do
      allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).
        and_return(10).at_least(1).times

      first_user = user_with_2fa
      second_user = user_with_2fa

      # Sign in as first user and setup remember device
      sign_in_after_remembering_device(first_user)
      expect(current_path).to eq(account_path)

      first(:link, t('links.sign_out')).click

      # Sign in as second user and expect otp confirmation
      sign_in_before_2fa(second_user)
      # TODO: Figure out how to incrase 2FA limit
      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

      # Setup remember device as second user
      check :remember_device
      click_submit_default

      first(:link, t('links.sign_out')).click

      # Sign in as first user again and expect otp confirmation
      sign_in_before_2fa(first_user)
      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
    end
  end

  def sign_in_after_remembering_device(user = user_with_2fa)
    sign_in_before_2fa(user)
    check :remember_device
    click_submit_default

    yield if block_given?

    first(:link, t('links.sign_out')).click
    sign_in_before_2fa(user)
  end
end
