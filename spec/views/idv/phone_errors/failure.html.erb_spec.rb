require 'rails_helper'

RSpec.describe 'idv/phone_errors/failure.html.erb' do
  let(:sp_name) { 'Example SP' }
  let(:timeout_hours) { 6 }
  let(:gpo_letter_available) { true }

  around do |ex|
    freeze_time { ex.run }
  end

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name:)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    assign(:gpo_letter_available, gpo_letter_available)
    allow(IdentityConfig.store).to receive(:idv_attempt_window_in_hours).and_return(timeout_hours)

    @expires_at = Time.zone.now + timeout_hours.hours

    render
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: MarketingSite.contact_url,
    )
  end

  it 'tells them they can try again later' do
    raw_expected_text = t(
      'idv.failure.phone.rate_limited.option_try_again_later_html',
      time_left: distance_of_time_in_words(Time.zone.now, @expires_at, except: :seconds),
    )
    expected_text = ActionView::Base.full_sanitizer.sanitize(raw_expected_text)

    expect(rendered).to have_text(expected_text)
  end

  it 'renders a cancel link' do
    expect(rendered).to have_link(
      t('links.cancel'),
      href: idv_cancel_path(step: :phone_error),
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
    raw_expected_text = t('idv.failure.phone.rate_limited.option_verify_by_mail_html')
    expected_text = ActionView::Base.full_sanitizer.sanitize(raw_expected_text)
    expect(rendered).to have_text(expected_text)
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
      raw_gpo_alternative = t('idv.failure.phone.rate_limited.option_verify_by_mail_html')
      gpo_alternative = ActionView::Base.full_sanitizer.sanitize(raw_gpo_alternative)

      expect(rendered).not_to have_text(gpo_alternative)
    end

    it 'does not include a link to GPO flow' do
      expect(rendered).not_to have_css(
        '.usa-button',
        text: t('idv.failure.phone.rate_limited.gpo.button'),
      )
    end
  end
end
