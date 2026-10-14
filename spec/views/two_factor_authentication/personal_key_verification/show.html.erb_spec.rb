require 'rails_helper'

RSpec.describe 'two_factor_authentication/personal_key_verification/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  before do
    @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
    @personal_key_form = PersonalKeyForm.new(user)
    allow(view).to receive(:current_user).and_return(user)
  end

  it_behaves_like 'an otp form'

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.enter_2fa_code.security_code'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered)
      .to have_content t('two_factor_authentication.personal_key_header_text')
  end

  it 'prompts the user to enter their personal key' do
    render

    expect(rendered)
      .to have_content t('two_factor_authentication.personal_key_prompt')
  end

  it 'contains a form to submit the personal key' do
    render

    expect(rendered).to have_button(t('forms.buttons.submit.default'))
    expect(rendered)
      .to have_xpath("//form[@action='#{login_two_factor_personal_key_path}']")
    expect(rendered)
      .to have_xpath("//form[@method='post']")
  end

  context 'when the personal key deprecation warning is shown' do
    before { @show_deprecation_warning = true }

    it 'renders a warning alert with the deprecation message' do
      render

      expect(rendered).to have_selector('.usa-alert--warning')
      expect(rendered)
        .to have_content(t('two_factor_authentication.personal_key_deprecation_warning'))
    end
  end

  context 'when the personal key deprecation warning is not shown' do
    before { @show_deprecation_warning = false }

    it 'does not render a warning alert' do
      render

      expect(rendered).to_not have_selector('.usa-alert--warning')
    end
  end
end
