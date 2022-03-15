require 'rails_helper'

describe 'idv/session_errors/failure.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:timeout_hours) { 6 }
  let(:in_person_proofing_enabled) { false }

  around do |ex|
    freeze_time { ex.run }
  end

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(IdentityConfig.store).to receive(:idv_attempt_window_in_hours).and_return(timeout_hours)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)

    @expires_at = Time.zone.now + timeout_hours.hours

    render
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
      href: return_to_sp_failure_to_proof_path(step: 'verify_info', location: 'failure'),
    )
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
