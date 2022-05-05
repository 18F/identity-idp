require 'rails_helper'

describe 'idv/phone_errors/warning.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:remaining_attempts) { 5 }
  let(:gpo_letter_available) { false }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    assign(:gpo_letter_available, gpo_letter_available)

    assign(:remaining_attempts, remaining_attempts)

    render
  end

  it 'shows warning text' do
    expect(rendered).to have_text(t('idv.failure.phone.warning'))
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: idv_phone_path)
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(t('idv.failure.attempts', count: remaining_attempts))
  end

  context 'gpo verification disabled' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'phone', location: 'warning'),
      )
      expect(rendered).not_to have_link(
        t('idv.troubleshooting.options.verify_by_mail'),
        href: idv_gpo_path,
      )
    end
  end

  context 'gpo verification enabled' do
    let(:gpo_letter_available) { true }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'phone', location: 'warning'),
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.verify_by_mail'),
        href: idv_gpo_path,
      )
    end
  end
end
