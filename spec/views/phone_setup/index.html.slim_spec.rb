require 'rails_helper'

describe 'users/phone_setup/index.html.erb' do
  before do
    user = build_stubbed(:user)

    allow(view).to receive(:current_user).and_return(user)

    @user_phone_form = UserPhoneForm.new(user, nil)
    @presenter = SetupPresenter.new(user, false)
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

  it 'it has auto enable off for the submit button' do
    expect(rendered).
      to have_xpath('//input[@type="submit" and contains(@class, "no-auto-enable")]')
  end
end
