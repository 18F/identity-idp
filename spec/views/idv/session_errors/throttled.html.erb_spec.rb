require 'rails_helper'

describe 'idv/session_errors/throttled.html.erb' do
  let(:sp_name) { nil }
  let(:liveness_checking_enabled) { false }
  let(:in_person_proofing_enabled) { false }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(view).to receive(:liveness_checking_enabled?).and_return(liveness_checking_enabled)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)

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

  context 'with in person proofing disabled' do
    let(:in_person_proofing_enabled) { false }

    it 'does not render an in person proofing link' do
      expect(rendered).not_to have_link(href: idv_in_person_url)
    end
  end

  context 'with in person proofing enabled' do
    let(:in_person_proofing_enabled) { true }

    it 'renders an in person proofing link' do
      expect(rendered).to have_link(
        t('in_person_proofing.link'),
        href: idv_in_person_url,
      )
    end
  end
end
