require 'rails_helper'

describe 'users/phone_setup/index.html.slim' do
  before do
    user = build_stubbed(:user)

    allow(view).to receive(:current_user).and_return(user)

    @user_phone_form = UserPhoneForm.new(user)
    @presenter = PhoneSetupPresenter.new('voice')
    render
  end

  it 'sets form autocomplete to off' do
    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'renders a link to choose a different option' do
    expect(rendered).to have_link(
      t('two_factor_authentication.choose_another_option'),
      href: two_factor_options_path
    )
  end
end
