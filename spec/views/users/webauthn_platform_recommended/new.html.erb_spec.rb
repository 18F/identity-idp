require 'rails_helper'

RSpec.describe 'users/webauthn_platform_recommended/new.html.erb' do
  subject(:rendered) { render }

  it 'renders separate forms with submission for options to add' do
    expect(rendered).to have_css('form:has(input[name=add_method]):has([type=submit])')
    expect(rendered).to have_css('form:not(:has(input[name=add_method])):has([type=submit])')
  end
end
