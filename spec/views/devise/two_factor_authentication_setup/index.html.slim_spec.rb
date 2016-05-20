require 'rails_helper'

describe 'devise/two_factor_authentication_setup/index.html.slim' do
  it 'sets form autocomplete to off' do
    @two_factor_setup_form = TwoFactorSetupForm.new(build_stubbed(:user))
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
