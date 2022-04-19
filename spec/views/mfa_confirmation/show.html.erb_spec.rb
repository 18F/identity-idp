require 'rails_helper'

describe 'mfa_confirmation/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      MfaConfirmationShowPresenter.new(
        current_user: user,
        next_path: phone_setup_url,
        final_path: account_url,
      ),
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.mfa_setup.first_authentication_method'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_content(t('titles.mfa_setup.first_authentication_method'))
  end

  it 'provides a call to action to add another MFA method' do
    render

    expect(rendered).to have_selector(
      'p',
      text: t('multi_factor_authentication.account_info', count: 1),
    )
  end

  it 'has a button with the ability to skip step' do
    render

    expect(rendered).to have_selector('button', text: t('multi_factor_authentication.skip'))
  end
end
