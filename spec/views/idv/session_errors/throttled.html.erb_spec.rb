require 'rails_helper'

describe 'idv/session_errors/throttled.html.erb' do
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:liveness_checking_enabled) { false }

  before do
    decorated_session = instance_double(
      ServiceProviderSessionDecorator,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(view).to receive(:liveness_checking_enabled?).and_return(liveness_checking_enabled)

    render
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: MarketingSite.contact_url,
      )
      expect(rendered).not_to have_link(href: return_to_sp_cancel_path)
    end
  end

  context 'with an SP' do
    let(:sp_name) { 'Example SP' }
    let(:sp_issuer) { 'example-issuer' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: MarketingSite.contact_url,
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'verify_info', location: 'throttled'),
      )
    end
  end

  context 'with liveness feature disabled' do
    let(:liveness_checking_enabled) { false }

    it 'renders expected heading' do
      expect(rendered).to have_text(t('errors.doc_auth.throttled_heading'))
    end
  end

  context 'with liveness feature enabled' do
    let(:liveness_checking_enabled) { true }

    it 'renders expected heading' do
      expect(rendered).to have_text(t('errors.doc_auth.throttled_heading'))
    end
  end
end
