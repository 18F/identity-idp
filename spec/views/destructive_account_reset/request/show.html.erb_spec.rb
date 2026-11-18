require 'rails_helper'

RSpec.describe 'destructive_account_reset/request/show.html.erb' do
  let(:interval) { '24 hours' }

  before do
    user = create(:user, :fully_registered, :with_personal_key)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:account_reset_deletion_period_interval, interval)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.request.delete_account'))

    render
  end

  it 'has button to delete' do
    render
    expect(rendered).to have_button t('destructive_account_reset.request.yes_continue')
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

    it 'renders the form-page heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('destructive_account_reset.request.delete_account'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.destructive_account_reset.request.intro'),
      )
    end

    it 'links to the help center article in a new tab' do
      expect(rendered).to have_link(
        t('destructive_account_reset.request.account_delete_link'),
        href: MarketingSite.help_center_article_url(
          category: 'manage-your-account',
          article: 'delete-your-account',
        ),
      )
      expect(rendered).to have_css('.auth__form-page-body a[target="_blank"]')
    end

    it 'describes both emails in a card with the waiting period' do
      expect(rendered).to have_css(
        '.auth__form-page-body h2',
        text: t('nds.destructive_account_reset.request.emails_heading'),
      )
      expect(rendered).to have_css(
        '.card h3',
        text: t('nds.destructive_account_reset.request.email1_heading'),
      )
      expect(rendered).to have_css(
        '.card h3',
        text: t('nds.destructive_account_reset.request.email2_heading'),
      )
      expect(rendered).to have_css(
        '.card p',
        text: t('nds.destructive_account_reset.request.email2_body', interval:),
      )
    end

    it 'posts to the account reset request path to continue' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_request_path}'][method='post'] " \
          "button.usa-button",
        text: t('nds.destructive_account_reset.request.continue'),
      )
    end

    it 'renders a tertiary cancel action to the root url' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{root_url}']",
        text: t('destructive_account_reset.request.no_cancel'),
      )
    end

    it 'does not render the legacy confirmation copy' do
      expect(rendered).not_to have_content(t('destructive_account_reset.request.continue_deletion'))
    end
  end
end
