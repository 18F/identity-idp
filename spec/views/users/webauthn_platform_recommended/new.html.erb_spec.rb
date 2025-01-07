require 'rails_helper'

RSpec.describe 'users/webauthn_platform_recommended/new.html.erb' do
  subject(:rendered) { render }

  it 'renders separate forms with submission for options to add' do
    expect(rendered).to have_css('form:has(input[name=add_method]):has([type=submit])')
    expect(rendered).to have_css('form:not(:has(input[name=add_method])):has([type=submit])')
  end

  it 'renders a help link for phishing-resistant including flow path' do
    @sign_in_flow = :example

    expect(rendered).to have_link(
      t('webauthn_platform_recommended.phishing_resistant'),
      href: help_center_redirect_path(
        category: 'get-started',
        article: 'authentication-methods',
        anchor: 'face-or-touch-unlock',
        flow: :example,
        step: :webauthn_platform_recommended,
      ),
    )
  end
end
