require 'rails_helper'

describe 'mfa_confirmation/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:enforce_second_mfa?).and_return(true)
    @content = MfaConfirmationPresenter.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.mfa_setup.suggest_second_mfa'))

    render
  end

  it 'has a heading' do
    render

    expect(rendered).to have_content(@content.heading)
  end

  it 'provides a context for adding another MFA method' do
    render

    expect(rendered).to have_selector(
      'p',
      class: 'margin-top-1 margin-bottom-4',
    )
  end

  it 'provides a call to action to add another MFA method' do
    render

    expect(rendered).to have_selector(
      'a',
      text: @content.button,
    )
  end

  it 'does not have a button with the ability to skip step' do
    render

    expect(rendered).to_not have_selector('button', text: t('mfa.skip'))
  end

  it 'does have a learn more link' do
    render

    expect(rendered).to have_selector('a', text: t('mfa.non_restricted.learn_more'))
  end

  context 'users with non restriced mfa' do
    let(:user) { create(:user, :signed_up, :with_authentication_app) }

    it 'does have a button with the ability to skip step' do
      render

      expect(rendered).to have_selector('button', text: t('mfa.skip'))
    end

    it 'does not have a learn more link' do
      render

      expect(rendered).to_not have_selector('a', text: t('mfa.non_restricted.learn_more'))
    end
  end
end
