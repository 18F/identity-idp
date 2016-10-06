require 'rails_helper'

feature 'Changing authentication factor' do
  describe 'requires re-authenticating' do
    before do
      sign_up_and_2fa
      allow(Figaro.env).to receive(:reauthn_window).and_return(0)
    end

    scenario 'editing password' do
      visit settings_password_path
      complete_2fa_confirmation

      expect(current_path).to eq settings_password_path
    end

    scenario 'editing phone number' do
      visit edit_phone_path
      complete_2fa_confirmation

      expect(current_path).to eq edit_phone_path
    end

    scenario 'editing email' do
      visit edit_email_path
      complete_2fa_confirmation

      expect(current_path).to eq edit_email_path
    end
  end

  def complete_2fa_confirmation
    allow(Figaro.env).to receive(:reauthn_window).and_return(10)

    expect(current_path).to eq user_password_confirm_path

    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_button t('headings.passwords.confirm')

    expect(current_path).to eq user_two_factor_authentication_path

    click_submit_default

    expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')

    click_submit_default
  end

  def click_submit_default
    click_button t('forms.buttons.submit.default')
  end
end
