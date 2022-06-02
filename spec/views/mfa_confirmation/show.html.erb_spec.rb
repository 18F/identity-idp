require 'rails_helper'

describe 'mfa_confirmation/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:enforce_second_mfa?).and_return(true)
    @content = MfaConfirmationPresenter.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.mfa_setup.suggest_second_mfa'))

    render
  end

  it 'has a localized header' do
    render
    puts rendered
    expect(rendered).to have_content(@content.heading)
  end

  it 'provides a call to action to add another MFA method' do
    render

    expect(rendered).to have_selector(
      'p',
      text: @content.info,
    )
  end

  # it 'has a button with the ability to skip step' do
  #   render

  #   expect(rendered).to have_selector('button', text: t('mfa.skip'))
  # end
end
