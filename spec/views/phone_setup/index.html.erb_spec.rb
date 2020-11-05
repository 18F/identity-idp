require 'rails_helper'

describe 'users/phone_setup/index.html.erb' do
  before do
    user = build_stubbed(:user)

    allow(view).to receive(:current_user).and_return(user)

    @new_phone_form = NewPhoneForm.new(user)

    @presenter = SetupPresenter.new(current_user: user,
                                    user_fully_authenticated: false,
                                    user_opted_remember_device_cookie: true,
                                    remember_device_default: true)
    render
  end

  it 'sets form autocomplete to off' do
    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'renders a link to choose a different option' do
    expect(rendered).to have_link(
      t('two_factor_authentication.choose_another_option'),
      href: two_factor_options_path,
    )
  end
end
