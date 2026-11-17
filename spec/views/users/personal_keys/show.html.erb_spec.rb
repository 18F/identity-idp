require 'rails_helper'

RSpec.describe 'users/personal_keys/show.html.erb' do
  let(:code) { '0193-0039-4739-9920' }
  let(:personal_key_generated_at) { Time.zone.parse('2026-06-25T14:03:00Z') }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:code, code)
    assign(:personal_key_generated_at, personal_key_generated_at)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.personal_key'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the legacy personal key partial posting to manage personal key' do
      expect(rendered).to have_css('h1', text: t('forms.personal_key_partial.header'))
      expect(rendered).to have_text(t('forms.personal_key.required_checkbox'))
      expect(rendered).to have_css("form[action='#{manage_personal_key_path}']")
      expect(rendered).to have_link(
        t('forms.personal_key_partial.acknowledgement.help_link_text'),
      )
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'has a title matching the personal key heading' do
      expect(view).to receive(:title=).with(t('forms.personal_key_partial.header'))

      render
    end

    it 'renders the form-page card with the heading and info' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('forms.personal_key_partial.header'),
      )
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('.auth__intro-description', text: t('nds.personal_key.info'))
    end

    it 'renders the key card with date, key, and copy/download/print actions' do
      render

      expect(rendered).to have_text(
        t(
          'nds.personal_key.generated_on',
          date: I18n.l(personal_key_generated_at, format: I18n.t('time.formats.event_date')),
        ),
      )
      expect(rendered).to have_css('.card p', text: '0193 - 0039 - 4739 - 9920')
      expect(rendered).to have_css(
        "lg-clipboard-button[clipboard-text='#{code}'] button",
        text: t('components.clipboard_button.label'),
      )
      expect(rendered).to have_css(
        "lg-click-observer[event-name='IdV: download personal key'] " \
        "a[download='personal_key.txt']",
        text: t('components.download_button.label'),
      )
      expect(rendered).to have_css(
        'lg-print-button button',
        text: t('components.print_button.label'),
      )
    end

    it 'posts the acknowledgment to manage personal key, gated on the checkbox' do
      render

      form = Nokogiri::HTML(rendered).at_css(
        "form[action='#{manage_personal_key_path}'][method='post'][data-nds-submit-gate]",
      )
      expect(form).to be_present
      expect(form.at_css('input.checkbox__input[name="acknowledgment"][required]')).to be_present
      expect(form.at_css('.checkbox__label-text').text)
        .to eq(t('nds.personal_key.acknowledgment'))
      expect(
        form.at_css(
          "lg-click-observer[event-name='IdV: personal key acknowledgment toggled'] " \
          "input[name='acknowledgment']",
        ),
      ).to be_present
      expect(form.at_css('.auth__actions button[type=submit]').text)
        .to include(t('forms.buttons.continue'))
    end

    it 'falls back to today when the key has no generation date' do
      assign(:personal_key_generated_at, nil)

      render

      expect(rendered).to have_text(
        t(
          'nds.personal_key.generated_on',
          date: I18n.l(Time.zone.today, format: I18n.t('time.formats.event_date')),
        ),
      )
    end

    it 'renders the account page notice in the card' do
      flash[:info] = t('account.personal_key.old_key_will_not_work')

      render

      expect(rendered).to have_css(
        '.auth--form-page .usa-alert--info',
        text: t('account.personal_key.old_key_will_not_work'),
      )
    end

    it 'does not render the legacy acknowledgment checkbox' do
      render

      expect(rendered).to_not have_text(t('forms.personal_key.required_checkbox'))
    end
  end
end
