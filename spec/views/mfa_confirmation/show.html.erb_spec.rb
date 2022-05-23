require 'rails_helper'

describe 'mfa_confirmation/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.mfa_setup.suggest_second_mfa'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_content(t('titles.mfa_setup.suggest_second_mfa'))
  end

  it 'provides a call to action to add another MFA method' do
    render

    expect(rendered).to have_selector(
      'p',
      text: t('mfa.account_info'),
    )
  end

  it 'has a button with the ability to skip step' do
    render

    expect(rendered).to have_selector('button', text: t('mfa.skip'))
  end
end
