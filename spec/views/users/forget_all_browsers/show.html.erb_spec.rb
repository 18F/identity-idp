require 'rails_helper'

RSpec.describe 'users/forget_all_browsers/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.forget_all_browsers'))

    render
  end

  it 'confirms with a DELETE to the forget all browsers path and links cancel to the account' do
    render

    expect(rendered).to have_content(t('account.forget_all_browsers.longer_description'))
    expect(rendered).to have_css(
      "form[action='#{forget_all_browsers_path}'] input[name=_method][value=delete]",
      visible: :all,
    )
    expect(rendered).to have_button(t('forms.buttons.confirm'))
    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end

  it 'does not render the NDS form page in the default layout' do
    render

    expect(rendered).to_not have_css('.auth--form-page')
    expect(view.content_for?(:nds_account_header)).to eq(false)
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the confirmation heading and description in the signed-in header' do
      render

      expect(view.content_for?(:nds_account_header)).to eq(true)
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('nds.dashboard_history.log_out_all_devices_heading'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.dashboard_history.log_out_all_devices_description'),
      )
    end

    it 'still confirms with a DELETE to the forget all browsers path' do
      render

      expect(rendered).to have_css(
        ".auth__actions form[method=post][action='#{forget_all_browsers_path}'] \
input[name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{forget_all_browsers_path}'] \
button.usa-button.usa-button--danger.usa-button--lg",
        text: t('forms.buttons.continue'),
      )
    end

    it 'links a secondary cancel back to History' do
      render

      expect(rendered).to have_css(
        ".auth__actions a.usa-button.usa-button--secondary[href='#{account_history_path}']",
        text: t('links.cancel'),
      )
    end
  end
end
