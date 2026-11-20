require 'rails_helper'

RSpec.describe 'shared/wait.html.erb' do
  let(:controller_path) { 'idv/verify_info' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:controller_path).and_return(controller_path)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.doc_auth.verify'))

    render
  end

  it 'refreshes the page every 15 seconds' do
    render

    expect(view.content_for(:meta_refresh)).to eq('15')
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to have_css('h1', text: t('doc_auth.info.interstitial_eta'))
    expect(rendered).to_not have_selector('.auth--form-page')
    expect(view.content_for(:nds_header_progress)).to be_nil
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the form-page card with the processing heading and copy' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('doc_auth.headings.interstitial'),
      )
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('doc_auth.info.interstitial_eta'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('doc_auth.info.interstitial_thanks'),
      )
    end

    it 'keeps the meta refresh and renders no actions, like the legacy page' do
      expect(view.content_for(:meta_refresh)).to eq('15')
      expect(rendered).to_not have_selector('.auth__actions')
      expect(rendered).to_not have_selector('form')
    end

    it 'sets the verification header progress to the verify info substep' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        '.progress__step[aria-current="step"] .progress__step-counter',
        text: '7 / 12',
      )
    end

    context 'while phone proofing is running' do
      let(:controller_path) { 'idv/phone' }

      it 'sets the verification header progress to the phone substep' do
        expect(view.content_for(:nds_header_progress)).to have_css(
          '.progress__step[aria-current="step"] .progress__step-counter',
          text: '8 / 12',
        )
      end
    end
  end
end
