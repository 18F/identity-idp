require 'rails_helper'

describe 'sign_up/personal_keys/show.html.slim' do
  before do
    @code = 'foo bar'
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.personal_key'))
    render
  end

  context 'personal key block' do
    before do
      render
    end

    it 'displays the personal key' do
      expect(rendered).to have_content 'foo'
      expect(rendered).to have_content 'bar'
    end

    it 'displays the personal key subheader' do
      expect(rendered).to have_content t('users.personal_key.header')
    end

    it 'displays the date the code was generated' do
      expect(rendered).to have_content(
        t('users.personal_key.generated_on_html',
          date: I18n.l(Time.zone.today, format: '%B %d, %Y'))
      )
    end
  end

  it 'has a localized heading' do
    render
    expect(rendered).to have_content t('headings.personal_key')
  end

  it 'informs the user of importance of keeping the personal key in a safe place' do
    render
    expect(rendered).to have_content(
      t('instructions.personal_key_html',
        accent: t('instructions.personal_key_accent'))
    )
  end

  it 'contains link to continue authenticating' do
    render

    expect(rendered).
      to have_content(t('forms.buttons.continue'))
  end

  it 'allows the user to print the personal key' do
    render

    expect(rendered).to have_xpath("//a[@data-print='true']")
    expect(rendered).to have_content(t('users.personal_key.print'))
  end

  it 'displays a button to get a new personal key' do
    render
    expect(rendered).to have_xpath("//input[@value='#{t('users.personal_key.get_another')}']")
    expect(rendered).to have_xpath("//form[@action='#{sign_up_personal_key_path}']")
  end
end
