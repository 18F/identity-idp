require 'rails_helper'

RSpec.describe 'users/backup_code_reminder/show.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('forms.backup_code_reminder.heading'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content(t('forms.backup_code_reminder.heading'))
  end

  it 'has localized body info' do
    render

    expect(rendered).to have_content(t('forms.backup_code_reminder.body_info'))
  end

  it 'has a cancel link to account path' do
    render

    expect(rendered).to have_button(t('forms.backup_code_reminder.have_codes'))
  end

  it 'has a regenerate backup code link' do
    render

    expect(rendered).to have_button(t('forms.backup_code_reminder.need_new_codes'))
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the illustration, heading and body' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header--with-media img.auth__media[aria-hidden=true]')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('forms.backup_code_reminder.heading'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('forms.backup_code_reminder.body_info'),
      )
    end

    it 'renders a primary have-codes submit above a secondary need-new-codes submit' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions form[action='#{backup_code_reminder_path}'][method=post]",
        count: 2,
      )
      expect(rendered).to have_css(
        '.actions form:nth-of-type(1) input[name=has_codes][value=true]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.actions form:nth-of-type(1) button.usa-button:not(.usa-button--secondary)',
        text: t('forms.backup_code_reminder.have_codes'),
      )
      expect(rendered).to have_css(
        '.actions form:nth-of-type(2) button.usa-button--secondary',
        text: t('forms.backup_code_reminder.need_new_codes'),
      )
      expect(rendered).to_not have_css(
        '.actions form:nth-of-type(2) input[name=has_codes]',
        visible: :all,
      )
    end
  end
end
