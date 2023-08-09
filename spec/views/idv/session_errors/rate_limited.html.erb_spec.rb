require 'rails_helper'

RSpec.describe 'idv/session_errors/rate_limited.html.erb' do
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }

  before do
    decorated_session = instance_double(
      ServiceProviderSessionDecorator,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    render
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: MarketingSite.contact_url,
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
        href: MarketingSite.contact_url,
      )
      expect(rendered).to have_link(
        t('idv.failure.exit.with_sp', app_name: APP_NAME, sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'rate_limited'),
      )
    end
  end

  context 'with liveness feature disabled' do
    it 'renders expected heading' do
      expect(rendered).to have_text(t('errors.doc_auth.rate_limited_heading'))
    end
  end

  context 'with liveness feature enabled' do
    it 'renders expected heading' do
      expect(rendered).to have_text(t('errors.doc_auth.rate_limited_heading'))
    end
  end
end
