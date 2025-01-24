require 'rails_helper'

RSpec.describe 'idv/socure/errors/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:remaining_submit_attempts) { 5 }
  let(:in_person_url) { nil }
  let(:flow_path) { :standard }
  let(:sp) { create(:service_provider) }
  let(:error_code) { nil }
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

  context 'timeout error' do
    let(:error_code) { :timeout }

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
      it 'does not have the IPP h1' do
        expect(rendered).not_to have_css('h1', text: t('in_person_proofing.headings.cta'))
      end

      it 'does not explain in person verification' do
        expect(rendered).not_to have_text(t('in_person_proofing.body.cta.prompt_detail'))
      end

      it 'does not render a secondary cta for IPP' do
        url = idv_in_person_direct_path

        expect(rendered).not_to have_link(
          t('in_person_proofing.body.cta.button'),
          href: %r{#{url}},
        )
      end
    end

    context 'In person verification enabled' do
      let(:sp) { create(:service_provider, in_person_proofing_enabled: true) }

      it 'has the IPP h1' do
        expect(rendered).to have_css('h1', text: t('in_person_proofing.headings.cta'))
      end

      it 'explains in person verification' do
        expect(rendered).to have_text(t('in_person_proofing.body.cta.prompt_detail'))
      end

      it 'has a secondary cta for IPP' do
        url = idv_in_person_direct_path
        expect(rendered).to have_link(
          t('in_person_proofing.body.cta.button'),
          href: %r{#{url}},
        )
      end
    end
  end

  context 'no capture app url' do
    let(:error_code) { :url_not_found }

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

    it 'does not show remaining attempts' do
      expect(rendered).not_to have_text(
        strip_tags(t('idv.failure.warning.attempts_html', count: remaining_submit_attempts)),
      )
    end
  end
end
