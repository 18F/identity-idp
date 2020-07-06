describe 'smoke test: sign in and out' do
  let(:monitor) { MonitorHelper.new(self) }

  before { monitor.setup }

  it 'creates account, signs out, signs back in' do
    visit monitor.idp_signup_url
    creds = monitor.create_new_account_with_sms
    page.first(:link, "Sign out").click
    monitor.sign_in_and_2fa(creds)

    expect(page).to have_content('Your account')
    expect(page.current_url).to include("#{monitor.idp_signin_url}/account")
  end
end
