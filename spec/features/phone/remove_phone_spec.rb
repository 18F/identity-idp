require 'rails_helper'

RSpec.feature 'removing a phone number from an account' do
  scenario 'deleting a phone number' do
    user = create(:user, :fully_registered, :with_piv_or_cac)
    phone_configuration = user.phone_configurations.first
    sign_in_and_2fa_user(user)
    visit manage_phone_path(id: phone_configuration.id)

    expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq true

    click_button t('forms.phone.buttons.delete')

    expect(page).to have_current_path(account_path)

    visit account_history_path
    expect(page).to have_content t('event_types.phone_removed')
    expect(PhoneConfiguration.find_by(id: phone_configuration.id)).to eq(nil)
    expect(MfaPolicy.new(user.reload).multiple_factors_enabled?).to eq false
  end

  context 'when deleting will mean the user will not have enough MFA methods' do
    scenario 'the option to delete the phone number is not available' do
      user = create(:user, :fully_registered)
      phone_configuration = user.phone_configurations.first
      sign_in_and_2fa_user(user)

      expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq false

      visit manage_phone_path(id: phone_configuration.id)

      expect(page).to_not have_button(t('forms.phone.buttons.delete'))
    end
  end
end
