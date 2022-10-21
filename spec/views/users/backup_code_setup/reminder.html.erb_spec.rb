require 'rails_helper'
require 'data_uri'

describe 'users/backup_code_setup/reminder.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with( \
      t('forms.backup_code.title'),
    )

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content \
      t('forms.backup_code_reminder.heading')
  end

  it 'has localized body info' do
    render

    expect(rendered).to have_content \
      t('forms.backup_code_reminder.body_info')
  end

  it 'has a cancel link to account path' do
    render

    expect(rendered).to have_button(t('forms.backup_code_reminder.have_codes'))
  end

  it 'has a regenerate backup code link' do
    render

    expect(rendered).to have_link(
      t('forms.backup_code_reminder.need_new_codes'),
      href: backup_code_regenerate_path,
    )
  end
end
