require 'rails_helper'

describe 'idv/session_errors/exception.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:in_person_proofing_enabled) { false }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: idv_doc_auth_path)
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
      href: return_to_sp_failure_to_proof_path(step: 'verify_info', location: 'exception'),
    )
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: MarketingSite.contact_url,
    )
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
        t('idv.troubleshooting.options.verify_in_person'),
        href: idv_in_person_url,
      )
    end
  end
end
