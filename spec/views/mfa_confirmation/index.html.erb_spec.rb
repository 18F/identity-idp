require 'rails_helper'

describe 'mfa_confirmation/index.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.mfa_setup.first_authentication_method'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_content(t('headings.mfa_setup.first_authentication_method'))
  end

  it 'provides a call to action to add another MFA method' do
    render

    expect(rendered).to have_selector('p', text: t('multi_factor_authentication.cta'))
  end

  it 'has a button with the next step' do
    render

    expect(rendered).to have_selector('button', text: t('multi_factor_authentication.add'))
  end
end
