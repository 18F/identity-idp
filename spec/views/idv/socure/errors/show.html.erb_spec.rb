require 'rails_helper'

RSpec.describe 'idv/socure/errors/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
  end

  let(:remaining_submit_attempts) { 5 }
  let(:in_person_url) { nil }
  let(:passport_requested) { false }
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
      passport_requested:,
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
        strip_tags(
          t(
            'doc_auth.rate_limit_warning_html',
            count: remaining_submit_attempts,
          ),
        ),
      )
    end

    it 'shows a primary action' do
      expect(rendered).to have_link(
        t('idv.failure.button.warning'),
        href: idv_socure_document_capture_path,
      )
    end

    context 'In person verification disabled' do
      let(:sp) { create(:service_provider, in_person_proofing_enabled: false) }

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
        strip_tags(
          t(
            'doc_auth.rate_limit_warning_html',
            count: remaining_submit_attempts,
          ),
        ),
      )
    end
  end

  context 'unexpected id type error' do
    let(:error_code) { :unexpected_id_type }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      assign(:presenter, presenter)

      render
    end

    context 'when passport is not requested' do
      it 'shows correct h1' do
        expect(rendered).to have_css(
          'h1',
          text: t('doc_auth.errors.verify_drivers_license_heading'),
        )
      end

      it 'shows unexpected_id_type message' do
        expect(rendered).to have_text(t('doc_auth.errors.verify_drivers_license_text'))
      end
    end

    context 'when passport is requested' do
      let(:passport_requested) { true }
      it 'shows correct h1' do
        expect(rendered).to have_css('h1', text: t('doc_auth.errors.verify_passport_heading'))
      end

      it 'shows unexpected_id_type message' do
        expect(rendered).to have_text(t('doc_auth.errors.verify_passport_text'))
      end
    end

    it 'shows remaining attempts' do
      expect(rendered).to have_text(
        strip_tags(
          t(
            'doc_auth.rate_limit_warning_html',
            count: remaining_submit_attempts,
          ),
        ),
      )
    end

    it 'shows a primary action' do
      expect(rendered).to have_link(
        t('idv.failure.button.warning'),
        href: idv_socure_document_capture_path,
      )
    end
  end

  context 'selfie fail error' do
    let(:error_code) { :selfie_fail }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      assign(:presenter, presenter)

      render
    end

    it 'shows correct h1' do
      expect(rendered).to have_css('h1', text: t('doc_auth.errors.selfie_fail_heading'))
    end

    it 'shows selfie failure message' do
      expect(rendered).to have_text(t('doc_auth.errors.general.selfie_failure'))
    end

    it 'shows remaining attempts' do
      expect(rendered).to have_text(
        strip_tags(
          t(
            'doc_auth.rate_limit_warning_html',
            count: remaining_submit_attempts,
          ),
        ),
      )
    end

    it 'shows a primary action' do
      expect(rendered).to have_link(
        t('idv.failure.button.warning'),
        href: idv_socure_document_capture_path,
      )
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }
    let(:error_code) { :network }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      assign(:presenter, presenter)
      render
    end

    it 'renders the warning card with attempts copy and no try-again-later text' do
      expect(rendered).to have_css('.auth--form-page h1', text: presenter.heading)
      expect(rendered).to have_css('.nds-status-icon--warning')
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: strip_tags(t('nds.socure_errors.rate_limit_html', count: remaining_submit_attempts)),
      )
      expect(rendered).not_to have_text(t('idv.errors.try_again_later'))
    end

    it 'renders try-again primary and use-another-ID secondary actions' do
      expect(rendered).to have_css(
        '.auth__actions a.usa-button:not(.usa-button--secondary)',
        text: t('idv.failure.button.warning'),
      )
      expect(rendered).to have_css(
        '.auth__actions a.usa-button--secondary',
        text: t('idv.troubleshooting.options.use_another_id_type'),
      )
    end

    it 'renders the in-person CTA with its heading and copy' do
      expect(rendered).to have_css('h2', text: t('nds.socure_errors.in_person_heading'))
      expect(rendered).to have_text(t('in_person_proofing.body.cta.prompt_detail'))
      expect(rendered).to have_css(
        'a.usa-button--secondary',
        text: t('in_person_proofing.body.cta.button'),
      )
    end

    it 'renders the remaining troubleshooting options as links' do
      expect(rendered).to have_css('h2', text: t('components.troubleshooting_options.ipp_heading'))
      expect(rendered).to have_css(
        'a.link[target=_blank]',
        text: t('idv.troubleshooting.options.doc_capture_tips'),
      )
      expect(rendered).to have_css(
        'a.link[target=_blank]',
        text: t('idv.troubleshooting.options.supported_documents'),
      )
      expect(rendered).to have_css(
        'a.link:not([target]) svg.usa-icon',
      )
    end

    it 'sets the verification header progress' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end
  end
end
