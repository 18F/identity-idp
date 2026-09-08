require 'rails_helper'

RSpec.describe 'idv/personal_key/show.html.erb' do
  let(:nds_layout) { false }
  let(:code) { '0193-0039-4739-9920' }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:step_indicator_steps)
      .and_return(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
    allow(view).to receive(:step_indicator_step).and_return(:secure_account)
    @code = code
    @personal_key_generated_at = Time.zone.today
    render
  end

  it 'renders the legacy heading and acknowledgment' do
    expect(rendered).to have_css('h1', text: t('forms.personal_key_partial.header'))
    expect(rendered).to have_text(t('forms.personal_key.required_checkbox'))
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the key card with date, key, and copy/download/print actions' do
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('forms.personal_key_partial.header'),
      )
      expect(rendered).to have_css('.auth__intro-description', text: t('nds.personal_key.info'))
      expect(rendered).to have_text(
        t(
          'nds.personal_key.generated_on',
          date: I18n.l(Time.zone.today, format: I18n.t('time.formats.event_date')),
        ),
      )
      expect(rendered).to have_css('.card p', text: '0193 - 0039 - 4739 - 9920')
      expect(rendered).to have_css(
        "lg-clipboard-button[clipboard-text='#{code}'] button",
        text: t('components.clipboard_button.label'),
      )
      expect(rendered).to have_css(
        "a[download='personal_key.txt']",
        text: t('components.download_button.label'),
      )
      expect(rendered).to have_css(
        'lg-print-button button',
        text: t('components.print_button.label'),
      )
    end

    it 'gates continue on the safe-place acknowledgment' do
      expect(rendered).to have_css(
        'input.checkbox__input[name="acknowledgment"][required]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.checkbox__label-text',
        text: t('nds.personal_key.acknowledgment'),
      )
      expect(rendered).to have_css(
        'form[data-nds-submit-gate] .auth__actions button[type=submit]',
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
