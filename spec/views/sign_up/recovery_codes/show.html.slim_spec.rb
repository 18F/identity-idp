require 'rails_helper'

describe 'sign_up/recovery_codes/show.html.slim' do
  before do
    @code = 'foo bar'
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.recovery_code'))
    render
  end

  context 'recovery code block' do
    before do
      render
    end

    it 'displays the recovery code' do
      expect(rendered).to have_content 'foo'
      expect(rendered).to have_content 'bar'
    end

    it 'displays the recovery code subheader' do
      expect(rendered).to have_content t('users.recovery_code.header')
    end

    it 'displays the date the code was generated' do
      expect(rendered).to have_content(
        t('users.recovery_code.generated_on_html',
          date: I18n.l(Time.zone.today, format: '%B %d, %Y'))
      )
    end
  end

  it 'has a localized heading' do
    render
    expect(rendered).to have_content t('headings.recovery_code')
  end

  it 'informs the user of importance of keeping the recovery code in a safe place' do
    render
    expect(rendered).to have_content(
      t('instructions.recovery_code_html',
        accent: t('instructions.recovery_code_accent'))
    )
  end

  it 'contains link to continue authenticating' do
    render

    expect(rendered).
      to have_xpath("//input[@value='#{t('forms.buttons.continue')}']")
    expect(rendered).
      to have_xpath("//form[@action='#{sign_up_recovery_code_path}']")
  end

  it 'allows the user to print the recovery code' do
    render

    expect(rendered).to have_xpath("//a[@data-print='true']")
    expect(rendered).to have_content(t('users.recovery_code.print'))
  end

  it 'displays a button to refresh the recovery code' do
    render
    expect(rendered).to have_link(
      t('users.recovery_code.get_another'),
      href: manage_recovery_code_path(resend: true)
    )
  end
end
