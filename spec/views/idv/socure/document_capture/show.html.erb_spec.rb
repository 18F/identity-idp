require 'rails_helper'

RSpec.describe 'idv/socure/document_capture/show.html.erb' do
  let(:nds_layout) { false }
  let(:url) { 'https://verify.socure.test/capture' }
  let(:passport_requested) { false }
  let(:mdl_requested) { false }
  let(:selfie_check_required) { false }
  let(:document_type_requested) { Idp::Constants::DocumentTypes::DRIVERS_LICENSE }
  let(:user_signing_up) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:user_signing_up?).and_return(user_signing_up)
    assign(:url, url)
    assign(:passport_requested, passport_requested)
    assign(:mdl_requested, mdl_requested)
    assign(:selfie_check_required, selfie_check_required)
    assign(:document_type_requested, document_type_requested)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.doc_auth.verify'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    it 'renders the legacy illustration, heading and step indicator' do
      expect(rendered).to have_css("img[src*='interstitial_icons']")
      expect(rendered).to have_css('h1', text: t('doc_auth.headings.document_capture'))
      expect(view.content_for(:pre_flash_content)).to have_css('lg-step-indicator')
    end

    it 'renders the Socure link inside the redirect click observer' do
      expect(rendered).to have_css(
        "lg-click-observer[event-name='idv_socure_docv_redirect_requested'] " \
        "a.usa-button[href='#{url}']",
        text: t('forms.buttons.continue'),
      )
    end

    it 'renders the cancel link' do
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'verify_id'))
    end

    context 'when an mDL is requested' do
      let(:mdl_requested) { true }

      it 'renders the mDL steps, alert and wallet button' do
        expect(rendered).to have_css('h1', text: t('doc_auth.headings.mdl_capture'))
        expect(rendered).to have_css('h2', text: t('idv.mdl.steps_heading'))
        expect(rendered).to have_css('.usa-alert--info')
        expect(rendered).to have_link(t('idv.mdl.button'), href: url)
      end
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    before { render }

    it 'renders the form-page card with the driver’s license heading and copy' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('doc_auth.headings.document_capture'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('doc_auth.info.socure_basic_idv', app_name: APP_NAME),
      )
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: t('doc_auth.info.socure_ial2_idv_finish', app_name: APP_NAME),
      )
    end

    it 'does not render the legacy illustration or step indicator' do
      expect(rendered).not_to have_css('img')
      expect(view.content_for(:pre_flash_content)).to be_nil
    end

    it 'sets the verification header progress' do
      progress = Capybara.string(view.content_for(:nds_header_progress))
      expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
      expect(progress).to have_css('.progress__step-counter', text: '4 / 12')
    end

    it 'renders the Socure link inside the redirect click observer with its payload' do
      observer = Capybara.string(rendered).find(
        ".auth__actions lg-click-observer[event-name='idv_socure_docv_redirect_requested']",
      )
      expect(JSON.parse(observer[:payload])).to eq(
        'document_type_requested' => document_type_requested,
      )
      expect(observer).to have_css(
        "a.usa-button[href='#{url}']",
        text: t('forms.buttons.continue'),
      )
    end

    it 'renders a tertiary cancel button to the cancel path' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{idv_cancel_path(step: 'verify_id')}']",
        text: t('links.cancel'),
      )
    end

    context 'when the user is signing up' do
      let(:user_signing_up) { true }

      it 'labels the cancel button for account creation' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{idv_cancel_path(step: 'verify_id')}']",
          text: t('links.cancel_account_creation'),
        )
      end
    end

    context 'when a passport is requested' do
      let(:passport_requested) { true }
      let(:document_type_requested) { Idp::Constants::DocumentTypes::PASSPORT }

      it 'renders the passport heading and copy' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('doc_auth.headings.passport_capture'),
        )
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: t('doc_auth.info.socure_passport', app_name: APP_NAME),
        )
        expect(rendered).to have_css(
          '.auth__form-page-body p',
          text: t('doc_auth.info.socure_ial2_idv_finish_passport', app_name: APP_NAME),
        )
        expect(rendered).to have_link(t('forms.buttons.continue'), href: url)
      end

      context 'with a selfie required' do
        let(:selfie_check_required) { true }

        it 'renders the passport-and-selfie copy' do
          expect(rendered).to have_css(
            '.auth__intro-description',
            text: t('doc_auth.info.socure_passport_ial2', app_name: APP_NAME),
          )
        end
      end
    end

    context 'when an mDL is requested' do
      let(:mdl_requested) { true }
      let(:document_type_requested) { Idp::Constants::DocumentTypes::MDL }

      it 'renders the mDL heading, copy, wallet alert and wallet button' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('nds.document_capture.mdl_heading'),
        )
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: t('nds.document_capture.mdl_subtitle'),
        )
        expect(rendered).to have_css(
          '.auth__form-page-body .usa-alert--info .usa-alert__heading',
          text: t('nds.document_capture.mdl_alert_title'),
        )
        expect(rendered).to have_css(
          '.auth__form-page-body .usa-alert--info .usa-alert__text',
          text: t('nds.document_capture.mdl_alert_body'),
        )
        expect(rendered).to have_css(
          ".auth__actions lg-click-observer a.usa-button[href='#{url}']",
          text: t('idv.mdl.button'),
        )
        expect(rendered).not_to have_content(t('forms.buttons.continue'))
      end
    end
  end
end
