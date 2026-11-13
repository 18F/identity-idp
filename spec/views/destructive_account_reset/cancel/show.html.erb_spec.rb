require 'rails_helper'

RSpec.describe 'destructive_account_reset/cancel/show.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.cancel_request.title'))

    render
  end

  it 'has button to cancel request' do
    render
    expect(rendered).to have_button t('destructive_account_reset.cancel_request.cancel_button')
  end

  it 'does not render the NDS form-page card' do
    render
    expect(rendered).not_to have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the warning badge, heading and confirmation question' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--warning')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('destructive_account_reset.cancel_request.title'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('destructive_account_reset.cancel_request.are_you_sure'),
      )
    end

    it 'posts to the cancel path from the primary action' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_cancel_path}'] button.usa-button",
        text: t('destructive_account_reset.cancel_request.cancel_button'),
      )
    end

    it 'renders a tertiary exit action to the root url' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{root_url}']",
        text: t('destructive_account_reset.cancel_request.cancel'),
      )
    end
  end
end
