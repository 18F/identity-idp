require 'rails_helper'

RSpec.describe 'idv/session_errors/rate_limited.html.erb' do
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    decorated_sp_session = instance_double(
      ServiceProviderSession,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)

    render
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: contact_redirect_url,
      )
      expect(rendered).to have_link(
        t('idv.failure.exit.without_sp', app_name: APP_NAME),
        href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'rate_limited'),
      )
    end
  end

  context 'with an SP' do
    let(:sp_name) { 'Example SP' }
    let(:sp_issuer) { 'example-issuer' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: contact_redirect_url,
      )
      expect(rendered).to have_link(
        t('idv.failure.exit.with_sp', app_name: APP_NAME, sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'rate_limited'),
      )
    end
  end

  context 'with liveness feature disabled' do
    it 'renders expected heading' do
      expect(rendered).to have_text(t('doc_auth.errors.rate_limited_heading'))
    end
  end

  context 'with liveness feature enabled' do
    it 'renders expected heading' do
      expect(rendered).to have_text(t('doc_auth.errors.rate_limited_heading'))
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the return-home exit as the primary action above troubleshooting' do
      expect(rendered).to have_css(
        '.auth__actions a.usa-button:not(.usa-button--tertiary)',
        text: t('nds.errors.return_home'),
      )
      expect(rendered).not_to have_css('.auth__form-page-body strong a')
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a.usa-button--tertiary[target=_blank]',
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
    end

    context 'with an SP' do
      let(:sp_name) { 'Example SP' }

      it 'uses the return-to-SP copy for the primary action' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button',
          text: t('idv.failure.exit.with_sp', app_name: APP_NAME, sp_name: sp_name),
        )
      end
    end
  end
end
