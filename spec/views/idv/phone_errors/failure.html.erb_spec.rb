require 'rails_helper'

RSpec.describe 'idv/phone_errors/failure.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:timeout_hours) { 6 }
  let(:gpo_letter_available) { true }

  around do |ex|
    freeze_time { ex.run }
  end

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    assign(:gpo_letter_available, gpo_letter_available)
    allow(IdentityConfig.store).to receive(:idv_attempt_window_in_hours).and_return(timeout_hours)

    @expires_at = Time.zone.now + timeout_hours.hours

    render
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
      href: return_to_sp_failure_to_proof_path(step: 'phone', location: 'failure'),
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
          'idv.failure.phone.rate_limited.body',
          time_left: distance_of_time_in_words(timeout_hours.hours),
        ),
      ),
    )
  end

  it 'describes GPO as an alternative' do
    expect(rendered).to have_text(t('idv.failure.phone.rate_limited.gpo.prompt'))
  end

  it 'includes a link to GPO flow' do
    expect(rendered).to have_css(
      '.usa-button',
      text: t('idv.failure.phone.rate_limited.gpo.button'),
    )
  end

  context 'GPO is not available' do
    let(:gpo_letter_available) { false }

    it 'does not describe GPO as an alternative' do
      expect(rendered).not_to have_text(t('idv.failure.phone.rate_limited.gpo.prompt'))
    end

    it 'does not include a link to GPO flow' do
      expect(rendered).not_to have_css(
        '.usa-button',
        text: t('idv.failure.phone.rate_limited.gpo.button'),
      )
    end
  end
end
