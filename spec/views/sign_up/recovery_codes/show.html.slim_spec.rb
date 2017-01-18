require 'rails_helper'

describe 'sign_up/recovery_codes/show.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.recovery_code'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content t('headings.recovery_code')
  end

  it 'informs the user of importance of keeping the recovery code in a safe place' do
    render

    expect(rendered).to have_content t('instructions.recovery_code')
  end

  it 'contains link to continue authenticating' do
    render

    expect(rendered).
      to have_xpath("//input[@value='#{t('forms.buttons.continue')}']")
    expect(rendered).
      to have_xpath("//form[@action='#{sign_up_recovery_code_path}']")
  end

  it 'displays the recovery code' do
    @code = 'foo'

    render

    expect(rendered).to have_content 'foo'
  end

  it 'displays the correct progress step when @show_progress_bar is true' do
    @show_progress_bar = true

    render

    expect(rendered).to have_css('.step-3.active')
  end

  it 'displays a button to refresh the recovery code' do
    render
    expect(rendered).to have_link(
      t('users.recovery_code.get_another'),
      manage_recovery_code_path(resend: true)
    )
  end
end
