require 'rails_helper'

describe 'two_factor_authentication/recovery_code_verification/show.html.slim' do
  it_behaves_like 'an otp form'

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.enter_2fa_code'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).
      to have_content t('devise.two_factor_authentication.recovery_code_header_text')
  end

  it 'prompts the user to enter their recovery code' do
    render

    expect(rendered).
      to have_content t('devise.two_factor_authentication.recovery_code_prompt')
  end

  it 'contains a form to submit the recovery code' do
    render

    expect(rendered).
      to have_xpath("//input[@value='#{t('forms.buttons.submit.default')}']")
    expect(rendered).
      to have_xpath("//form[@action='#{login_two_factor_recovery_code_path}']")
    expect(rendered).
      to have_xpath("//form[@method='post']")
  end
end
