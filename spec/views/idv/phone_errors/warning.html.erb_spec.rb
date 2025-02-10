require 'rails_helper'

RSpec.describe 'idv/phone_errors/warning.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:sp_name) { 'Example SP' }
  let(:remaining_submit_attempts) { 5 }
  let(:gpo_letter_available) { false }
  let(:phone) { '+13602345678' }
  let(:country_code) { 'US' }
  let(:formatted_phone) { '+1 360-234-5678' }

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    assign(:gpo_letter_available, gpo_letter_available)
    assign(:remaining_submit_attempts, remaining_submit_attempts)
    assign(:country_code, country_code)
    assign(:phone, phone)

    render
  end

  it 'shows correct h1' do
    expect(rendered).to have_css('h1', text: t('idv.failure.phone.warning.heading'))
  end

  it 'shows number entered' do
    expect(rendered).to have_text(t('idv.failure.phone.warning.you_entered'))
    expect(rendered).to have_text(formatted_phone)
  end

  it 'shows next steps' do
    expect(rendered).to include(t('idv.failure.phone.warning.next_steps_html'))
  end

  it 'links to help screen' do
    expect(rendered).to have_link(
      t('idv.failure.phone.warning.learn_more_link'),
      href: help_center_redirect_path(
        category: 'verify-your-identity',
        article: 'phone-number',
        flow: :idv,
        step: :phone,
        location: 'learn_more',
      ),
    )
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'idv.failure.warning.attempts_html',
          count: remaining_submit_attempts,
        ),
      ),
    )
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(
      t('idv.failure.phone.warning.try_again_button'),
      href: idv_phone_path,
    )
  end

  context 'gpo verification disabled' do
    it 'does not render link to gpo flow' do
      expect(rendered).not_to have_link(
        t('idv.troubleshooting.options.verify_by_mail'),
        href: idv_request_letter_path,
      )
    end
  end

  context 'gpo verification enabled' do
    let(:gpo_letter_available) { true }

    it 'has an h2' do
      expect(rendered).to have_css('h2', text: t('idv.failure.phone.warning.gpo.heading'))
    end

    it 'explains gpo' do
      expect(rendered).to have_text(
        t('idv.failure.phone.warning.gpo.explanation'),
      )
    end

    it 'says how long gpo takes' do
      expect(rendered).to have_text(
        strip_tags(t('idv.failure.phone.warning.gpo.how_long_it_takes_html')),
      )
    end

    it 'has a secondary cta' do
      expect(rendered).to have_link(
        t('idv.failure.phone.warning.gpo.button'),
        href: idv_request_letter_path,
      )
    end
  end

  context 'no phone' do
    let(:phone) { nil }
    it 'does not render "You entered:"' do
      expect(rendered).not_to have_text(t('idv.failure.phone.warning.you_entered'))
    end
  end
end
