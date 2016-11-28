require 'rails_helper'

describe 'two_factor_authentication/recovery_code/show.html.slim' do
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
      to have_xpath("//input[@value='#{t('forms.buttons.acknowledge_recovery_code')}']")
    expect(rendered).
      to have_xpath("//form[@action='#{acknowledge_recovery_code_path}']")
  end

  it 'displays the recovery code' do
    @code = 'foo'

    render

    expect(rendered).to have_content 'foo'
  end

  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-3.active')
  end
end
