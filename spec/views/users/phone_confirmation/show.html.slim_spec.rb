require 'rails_helper'

describe 'users/phone_confirmation/show.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'informs the user that a confirmation code has been sent' do
    @unconfirmed_phone = '12345'
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

  context 'when choosing to receive OTP via SMS' do
    before do
      @sms_enabled = true
      @fallback_confirmation_link = '/users/phone_confirmation/send?delivery_method=voice'
    end

    it 'has a link to send confirmation with voice' do
      render

      expect(rendered).to have_link('call me with the one-time passcode',
                                    href: '/users/phone_confirmation/send?delivery_method=voice')
    end
  end

  context 'when choosing to receive OTP via voice' do
    before do
      @sms_enabled = false
      @fallback_confirmation_link = '/users/phone_confirmation/send?delivery_method=sms'
    end

    it 'has a link to send confirmation as SMS' do
      render

      expect(rendered).to have_link('send me a text message with the one-time ' \
        'passcode', href: '/users/phone_confirmation/send?delivery_method=sms')
    end
  end
end
