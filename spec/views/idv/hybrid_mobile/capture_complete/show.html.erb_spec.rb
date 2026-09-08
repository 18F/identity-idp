require 'rails_helper'

RSpec.describe 'idv/hybrid_mobile/capture_complete/show.html.erb' do
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    render
  end

  it 'renders the legacy switch-back heading and illustration' do
    expect(rendered).to have_css('h1', text: t('doc_auth.instructions.switch_back'))
    expect(rendered).to have_css("img[src*='switch-back-to-computer']")
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the heading and success copy without the legacy illustration' do
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('titles.doc_auth.switch_back'),
      )
      expect(rendered).to have_css('.auth__intro-description', text: t('nds.capture_complete.info'))
      expect(rendered).not_to have_css('img')
    end

    it 'sets the verification header progress' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end
  end
end
