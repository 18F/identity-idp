require 'rails_helper'

RSpec.describe 'idv/socure/document_capture/wait.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.doc_auth.verify'))

    render
  end

  it 'refreshes the page every 15 seconds by default' do
    render

    expect(view.content_for(:meta_refresh)).to eq('15')
  end

  it 'refreshes the page at the controller-provided interval' do
    assign(:refresh_interval, 7)

    render

    expect(view.content_for(:meta_refresh)).to eq('7')
  end

  context 'in the default layout' do
    before { render }

    it 'renders the verify ID step indicator' do
      expect(view.content_for(:pre_flash_content)).to have_css(
        'lg-step-indicator .step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )
    end

    it 'renders the illustration, heading and processing copy' do
      expect(rendered).to have_css("img[src*='id-card'][alt='']")
      expect(rendered).to have_css('h1', text: t('doc_auth.headings.interstitial'))
      expect(rendered).to have_content(t('doc_auth.info.interstitial_eta'))
      expect(rendered).to have_content(t('doc_auth.info.interstitial_thanks'))
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
      expect(view.content_for(:nds_header_progress)).to be_nil
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the processing heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('doc_auth.headings.interstitial'),
      )
    end

    it 'renders the processing copy' do
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('doc_auth.info.interstitial_eta'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('doc_auth.info.interstitial_thanks'),
      )
    end

    it 'sets the verification header progress to the document capture substep' do
      progress = view.content_for(:nds_header_progress)
      expect(progress).to have_css(
        'nds-progress .progress__step[aria-current="step"] .progress__step-counter',
        text: '4 / 12',
      )
    end

    it 'keeps the meta refresh and drops the legacy step indicator and illustration' do
      expect(view.content_for(:meta_refresh)).to eq('15')
      expect(view.content_for(:pre_flash_content)).to be_nil
      expect(rendered).to_not have_css('img')
    end

    it 'renders no actions, like the legacy page' do
      expect(rendered).to_not have_selector('.auth__actions')
      expect(rendered).to_not have_selector('form')
      expect(rendered).to_not have_selector('a')
    end
  end
end
