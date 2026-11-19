require 'rails_helper'

RSpec.describe 'idv/hybrid_mobile/socure/document_capture/show.html.erb' do
  let(:nds_layout) { false }
  let(:url) { 'https://verify.socure.test/capture' }
  let(:mdl_requested) { false }
  let(:document_type_requested) { Idp::Constants::DocumentTypes::DRIVERS_LICENSE }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:user_signing_up?).and_return(false)
    assign(:hybrid_flow, true)
    assign(:url, url)
    assign(:passport_requested, false)
    assign(:mdl_requested, mdl_requested)
    assign(:selfie_check_required, false)
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

    it 'renders the legacy heading, Socure link and cancel link' do
      expect(rendered).to have_css('h1', text: t('doc_auth.headings.document_capture'))
      expect(rendered).to have_css(
        "lg-click-observer[event-name='idv_socure_docv_redirect_requested'] " \
        "a.usa-button[href='#{url}']",
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'verify_id'))
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    before { render }

    it 'renders the form-page card with the heading, Socure link and cancel button' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('doc_auth.headings.document_capture'),
      )
      expect(rendered).to have_css(
        ".auth__actions lg-click-observer[event-name='idv_socure_docv_redirect_requested'] " \
        "a.usa-button[href='#{url}']",
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{idv_cancel_path(step: 'verify_id')}']",
        text: t('links.cancel'),
      )
    end

    it 'sets the verification header progress' do
      progress = Capybara.string(view.content_for(:nds_header_progress))
      expect(progress).to have_css('.progress__step-counter', text: '4 / 12')
    end

    context 'when an mDL is requested' do
      let(:mdl_requested) { true }
      let(:document_type_requested) { Idp::Constants::DocumentTypes::MDL }

      it 'renders the mDL heading and wallet button' do
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('nds.document_capture.mdl_heading'),
        )
        expect(rendered).to have_css(
          ".auth__actions lg-click-observer a.usa-button[href='#{url}']",
          text: t('idv.mdl.button'),
        )
      end
    end
  end
end
