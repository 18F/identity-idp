describe 'smoke test: sign in and out' do
  include MonitorIdpSteps

  let(:monitor) { MonitorHelper.new(self) }

  before { monitor.setup }

  it 'creates account, signs out, signs back in' do
    visit monitor.idp_signup_url
    email_address, totp_secret = create_new_account_with_totp
    page.first(:link, 'Sign out').click
    sign_in_and_2fa(email_address, totp_secret)

    expect(page).to have_content('Your account')
    expect(page.current_url).to include("#{monitor.config.idp_signin_url}/account")
  end
end
