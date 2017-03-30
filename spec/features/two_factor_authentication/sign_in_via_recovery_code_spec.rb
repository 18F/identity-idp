require 'rails_helper'

feature 'Signing in via recovery code' do
  it 'displays new recovery code and redirects to profile after acknowledging' do
    user = create(:user, :signed_up)
    sign_in_before_2fa(user)

    code = RecoveryCodeGenerator.new(user).create

    click_link t('devise.two_factor_authentication.recovery_code_fallback.link')

    enter_recovery_code(code: code)

    click_submit_default
    click_acknowledge_recovery_code

    expect(user.reload.recovery_code).to_not eq code
    expect(current_path).to eq profile_path
  end

  context 'user enters incorrect recovery code' do
    it 'locks user out when max login attempts has been reached' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
      code = RecoveryCodeGenerator.new(user).create
      wrong_recovery_code = code.split(' ').reverse.join

      click_link t('devise.two_factor_authentication.recovery_code_fallback.link')
      enter_recovery_code(code: wrong_recovery_code)
      click_submit_default

      expect(page).to have_content(
        t('devise.two_factor_authentication.max_personal_key_login_attempts_reached')
      )
    end
  end
end
