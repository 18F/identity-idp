require 'rails_helper'

RSpec.describe 'completions_cancellation/show.html.erb' do
  let(:sp_name) { 'Test Service Provider' }
  let(:decorated_sp_session) { instance_double(ServiceProviderSession, sp_name:) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.cancel_exit_login', app_name: APP_NAME))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the warning status page heading' do
      expect(rendered).to have_css(
        'h1',
        text: t('headings.cancellations.login_cancel_prompt', app_name: APP_NAME),
      )
    end

    it 'names the service provider and links to the account page' do
      expect(rendered).to have_css('ul.usa-list li strong', text: sp_name)
      expect(rendered).to have_link(t('login_cancel.account_page'), href: account_path)
    end

    it 'renders the keep going and exit buttons' do
      expect(rendered).to have_link(t('login_cancel.keep_going'), href: sign_up_completed_path)
      expect(rendered).to have_link(
        t('login_cancel.exit', app_name: APP_NAME),
        href: return_to_sp_cancel_path(step: :sign_up),
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the warning badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--warning')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('headings.cancellations.login_cancel_prompt', app_name: APP_NAME),
      )
    end

    it 'renders the divider and both consequences with the SP name and account link' do
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: t('login_cancel.header', app_name: APP_NAME),
      )
      expect(rendered).to have_css('.auth__form-page-body ul.usa-list li', count: 2)
      expect(rendered).to have_css('.auth__form-page-body li strong', text: sp_name)
      expect(rendered).to have_css(
        ".auth__form-page-body li a[href='#{account_path}']",
        text: t('login_cancel.account_page'),
      )
    end

    it 'renders a primary keep going action back to the completions page' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{sign_up_completed_path}']",
        text: t('login_cancel.keep_going'),
      )
      expect(rendered).not_to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{sign_up_completed_path}']",
      )
    end

    it 'renders a tertiary exit action to the SP cancel path' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--tertiary[href='#{return_to_sp_cancel_path(step: :sign_up)}']",
        text: t('login_cancel.exit', app_name: APP_NAME),
      )
    end

    it 'renders the actions in legacy order' do
      expect(rendered.index(t('login_cancel.keep_going')))
        .to be < rendered.index(t('login_cancel.exit', app_name: APP_NAME))
    end

    it 'does not render the legacy status page' do
      expect(rendered).not_to have_css('.usa-button--outline')
      expect(rendered).not_to have_css('.grid-row')
    end
  end
end
