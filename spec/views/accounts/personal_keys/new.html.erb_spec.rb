require 'rails_helper'

RSpec.describe 'accounts/personal_keys/new.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('account.personal_key.get_new'))

    render
  end

  it 'renders the legacy continue button and cancel link' do
    render

    expect(rendered).to have_css(
      "form[action='#{create_new_personal_key_path}'] button",
      text: t('forms.buttons.continue'),
    )
    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end

  it 'does not render the NDS form page in the default layout' do
    render

    expect(rendered).to_not have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the heading and description in the signed-in header layout' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
      expect(rendered).to have_css('.auth--form-page h1', text: t('account.personal_key.get_new'))
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('account.personal_key.get_new_description'),
      )
    end

    it 'posts with a primary Continue above a tertiary Cancel' do
      render

      expect(rendered).to have_css(
        ".auth__actions form[action='#{create_new_personal_key_path}'][method=post] " \
          "button.usa-button:not(.usa-button--secondary)",
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to_not have_css('.auth__actions form [name=_method]', visible: :all)
      expect(rendered).to have_link(
        t('links.cancel'),
        href: account_path,
        class: 'usa-button--tertiary',
      )
    end
  end
end
