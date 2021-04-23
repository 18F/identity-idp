require 'rails_helper'

describe 'idv/session_errors/recovery_exception.html.erb' do
  let(:sp_name) { 'Example SP' }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: idv_recovery_path)
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('two_factor_authentication.account_reset.reset_your_account'),
      href: account_reset_request_path,
    )
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
      href: return_to_sp_failure_to_proof_path,
    )
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app: APP_NAME),
      href: MarketingSite.contact_url,
    )
  end
end
