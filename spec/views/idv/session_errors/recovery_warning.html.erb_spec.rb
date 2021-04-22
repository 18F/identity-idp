require 'rails_helper'

describe 'idv/session_errors/recovery_warning.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:remaining_step_attempts) { 5 }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    assign(:remaining_step_attempts, remaining_step_attempts)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: idv_recovery_path)
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(t('idv.failure.attempts', count: remaining_step_attempts))
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
  end
end
