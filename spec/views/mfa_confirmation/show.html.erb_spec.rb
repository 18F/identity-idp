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
end
