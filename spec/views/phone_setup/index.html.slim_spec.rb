require 'rails_helper'

describe 'users/phone_setup/index.html.slim' do
  before do
    user = build_stubbed(:user, otp_delivery_preference: 'voice')

    allow(view).to receive(:current_user).and_return(user)

    @user_phone_form = UserPhoneForm.new(user)
    @presenter = PhoneSetupPresenter.new(user)
    render
  end

  it 'sets form autocomplete to off' do
    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'renders a link to choose a different option' do
    expect(rendered).to have_link(
      t('devise.two_factor_authentication.two_factor_choice_cancel'),
      href: two_factor_options_path
    )
  end
end
