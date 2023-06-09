require 'rails_helper'

RSpec.describe 'editing a phone' do
  it 'allows a user to edit one of their phone numbers' do
    user = create(:user, :fully_registered)
    phone_configuration = user.phone_configurations.first
    sign_in_and_2fa_user(user)

    visit(manage_phone_path(id: phone_configuration.id))

    expect(page).to have_content(t('headings.edit_info.phone'))
    expect(current_path).to eq(manage_phone_path(id: phone_configuration.id))
  end

  it "does not allow a user to edit another user's phone number" do
    user = create(:user, :fully_registered)
    sign_in_and_2fa_user(user)

    visit(manage_phone_path(id: create(:phone_configuration).id))

    expect(page).to have_content('The page you were looking for doesn’t exist')
  end

  context 'with only one phone number' do
    it 'does not allow you to check default phone number if only one number is set up' do
      user = create(:user, :fully_registered)
      phone_configuration = user.phone_configurations.first
      sign_in_and_2fa_user(user)

      visit(manage_phone_path(id: phone_configuration.id))
      expect(page).to have_field(
        t('two_factor_authentication.otp_make_default_number.label'),
        disabled: true,
      )
    end
  end
end
