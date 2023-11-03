require 'rails_helper'

RSpec.describe 'mfa_confirmation/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:enforce_second_mfa?).and_return(true)
    @content = MfaConfirmationPresenter.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.mfa_setup.suggest_second_mfa'))

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

  it 'has link to skip add mfa' do
    render

    expect(rendered).to have_button(
      t('mfa.skip'),
    )
  end

  context 'when the user only has enabled mfa webauthn platform' do
    let(:user) { create(:user, :with_webauthn_platform) }

    before do
      @content = MfaConfirmationPresenter.new(
        show_skip_additional_mfa_link: false,
      )
    end

    it 'does not show link to skip add mfa' do
      render

      expect(rendered).not_to have_button(
        t('mfa.skip'),
      )
    end
  end
end
