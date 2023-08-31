require 'rails_helper'

RSpec.describe 'idv/session_errors/failure.html.erb' do
  let(:sp_name) { nil }
  let(:timeout_hours) { 6 }

  around do |ex|
    freeze_time { ex.run }
  end

  before do
    allow(IdentityConfig.store).to receive(:idv_attempt_window_in_hours).and_return(timeout_hours)

    @expires_at = Time.zone.now + timeout_hours.hours
    @sp_name = sp_name

    render
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: MarketingSite.contact_url,
    )
  end

  it 'includes a message instructing when they can try again' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'idv.failure.sessions.fail_html',
          timeout: distance_of_time_in_words(timeout_hours.hours),
        ),
      ),
    )
  end

  it 'links back to the failure_to_proof URL' do
    expect(rendered).to have_link(
      t('idv.failure.exit.without_sp'),
      href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'failure'),
    )
  end

  context 'with an associated service provider' do
    let(:sp_name) { 'Example SP' }

    it 'links back to the SP failure_to_proof URL' do
      expect(rendered).to have_link(
        t(
          'idv.failure.exit.with_sp',
          sp_name: sp_name,
          app_name: 'Login.gov',
        ),
        href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'failure'),
      )
    end
  end
end
