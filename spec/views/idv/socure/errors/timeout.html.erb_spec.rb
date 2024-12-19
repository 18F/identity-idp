require 'rails_helper'

RSpec.describe 'idv/socure/errors/timeout.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:remaining_submit_attempts) { 5 }
  let(:in_person_url) { nil }
  let(:error_code) { :timeout }
  let(:flow_path) { :standard }
  let(:sp) { create(:service_provider) }
  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp:,
      view_context: nil,
      sp_session: nil,
      service_provider_request: nil,
    )
  end
  let(:presenter) do
    SocureErrorPresenter.new(
      error_code:,
      remaining_attempts: remaining_submit_attempts,
      sp_name: decorated_sp_session&.sp_name || APP_NAME,
      issuer: decorated_sp_session&.sp_issuer,
      flow_path:,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    assign(:presenter, presenter)

    render
  end

  it 'shows correct h1' do
    expect(rendered).to have_css('h1', text: t('idv.errors.technical_difficulties'))
  end

  it 'shows try again' do
    expect(rendered).to have_text(t('idv.errors.try_again_later'))
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(
      strip_tags(t('idv.failure.warning.attempts_html', count: remaining_submit_attempts)),
    )
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(
      t('idv.failure.button.warning'),
      href: idv_socure_document_capture_path,
    )
  end

  context 'In person verification disabled' do
    it 'does not render link to in person flow' do
      url = idv_in_person_direct_path

      expect(rendered).not_to have_link(
        t('in_person_proofing.body.cta.button'),
        href: %r{#{url}},
      )
    end
  end

  context 'In person verification enabled' do
    let(:sp) { create(:service_provider, in_person_proofing_enabled: true) }

    it 'has an h1' do
      expect(rendered).to have_css('h1', text: t('in_person_proofing.headings.cta'))
    end

    it 'explains in person verification' do
      expect(rendered).to have_text(t('in_person_proofing.body.cta.prompt_detail'))
    end

    it 'has a secondary cta' do
      url = idv_in_person_direct_path
      expect(rendered).to have_link(
        t('in_person_proofing.body.cta.button'),
        href: %r{#{url}},
      )
    end
  end
end
