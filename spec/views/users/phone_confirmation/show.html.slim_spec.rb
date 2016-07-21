require 'rails_helper'

describe 'users/phone_confirmation/show.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'informs the user that a confirmation code has been sent' do
    @unconfirmed_mobile = '12345'
    render

    expect(rendered).to have_content('Please enter the code sent to 12345')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.enter_2fa_code'))

    render
  end

  it 'asks the user to confirm their phone number' do
    render

    expect(rendered).to have_content(t('forms.phone_confirmation.header_text'))
  end

  it 'allows user to resend code' do
    render

    expect(rendered).to have_link('Resend', href: phone_confirmation_send_path)
  end

  it 'allows user to re-enter phone number' do
    @reenter_phone_number_path = 'reenter_url'
    render

    expect(rendered).to have_link('Try again', href: 'reenter_url')
  end

  context 'when @code_value is set' do
    before { @code_value = '12777' }

    it 'pre-populates the form field' do
      render

      expect(rendered).to have_xpath("//input[@value='12777']")
    end
  end
end
