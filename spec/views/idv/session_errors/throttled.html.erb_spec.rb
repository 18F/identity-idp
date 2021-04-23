require 'rails_helper'

describe 'idv/session_errors/throttled.html.erb' do
  let(:sp_name) { nil }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    render
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app: APP_NAME),
        href: MarketingSite.contact_url,
      )
      expect(rendered).not_to have_link(href: return_to_sp_cancel_path)
    end
  end

  context 'with an SP' do
    let(:sp_name) { 'Example SP' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app: APP_NAME),
        href: MarketingSite.contact_url,
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path,
      )
    end
  end
end
