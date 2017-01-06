require 'rails_helper'

describe 'users/two_factor_authentication_setup/index.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    @two_factor_setup_form = TwoFactorSetupForm.new(user)
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-3.active')
  end
end
