require 'rails_helper'

RSpec.describe 'idv/verify_info/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:nds_layout) { false }
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT.dup }
  let(:ssn) { '900-12-1234' }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:user_signing_up?).and_return(false)
    @pii = pii
    @ssn = ssn
    @step_indicator_steps = Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS
    @had_barcode_read_failure = false
    render
  end

  it 'renders the legacy heading and submit' do
    expect(rendered).to have_css('h1', text: t('headings.verify'))
    expect(rendered).to have_button(t('forms.buttons.submit.default'))
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the review card with labeled rows and edit actions' do
      expect(rendered).to have_css('.auth--form-page h1', text: t('headings.verify'))
      expect(rendered).to have_css('.card--elevated .nds-summary__row', count: 6)
      expect(rendered).to have_css('.nds-summary__label', text: t('nds.verify_info.address'))
      expect(rendered).to have_link(t('forms.buttons.edit'), href: idv_address_url)
      expect(rendered).to have_link(t('forms.buttons.edit'), href: idv_ssn_url)
    end

    it 'masks the SSN to the last four digits with a reveal toggle' do
      expect(rendered).to have_css('[data-nds-masked] [data-masked="true"]', text: '•••-••-1234')
      expect(rendered).to have_css(
        '[data-nds-masked] [data-masked="false"]', text: ssn,
                                                   visible: :all
      )
      expect(rendered).to have_css('button[data-nds-masked-toggle][aria-pressed="false"]')
    end

    it 'keeps the form-steps-wait continue button' do
      expect(rendered).to have_css(
        'form[data-form-steps-wait] button',
        text: t('forms.buttons.continue'),
      )
    end

    it 'sets the verification header progress' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end
  end
end
