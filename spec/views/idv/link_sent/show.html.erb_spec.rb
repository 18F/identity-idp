require 'rails_helper'

RSpec.describe 'idv/link_sent/show.html.erb' do
  let(:nds_layout) { false }
  let(:polling) { true }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(polling)
    render template: 'idv/link_sent/show', locals: { phone: '(202) 555-1212' }
  end

  it 'renders the legacy heading and continue form' do
    expect(rendered).to have_css('h1', text: t('doc_auth.headings.text_message'))
    expect(rendered).to have_button(t('forms.buttons.continue'))
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the connected-phone card with instructions' do
      expect(rendered).to have_css('.card.card--elevated h1', text: t('nds.link_sent.heading'))
      expect(rendered).to have_css("img[src*='devices'][width='87'][height='65']")
      expect(rendered).to have_text(t('nds.link_sent.instructions'))
      expect(rendered).to have_text(t('nds.link_sent.keep_open'))
      expect(rendered).not_to have_text(t('doc_auth.info.you_entered'))
    end

    it 'sets the verification header progress' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end

    it 'keeps the continue form and polling hook' do
      expect(rendered).to have_css(
        "form.link-sent-continue-button-form[action='#{idv_link_sent_url}']",
      )
      expect(rendered).to have_css(
        "script[data-status-endpoint='#{idv_link_sent_poll_url}']",
        visible: :all,
      )
    end

    context 'without polling' do
      let(:polling) { false }

      it 'omits the polling hook' do
        expect(rendered).not_to have_css('script[data-status-endpoint]', visible: :all)
      end
    end
  end
end
