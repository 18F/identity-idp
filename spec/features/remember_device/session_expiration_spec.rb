require 'rails_helper'

describe 'signing in with remember device and idling on the sign in page' do
  include SamlAuthHelper

  it 'redirects to the OIDC SP even though session is deleted' do
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('1000')

    # We want to simulate a user that has already visited an OIDC SP and that
    # has checked "remember me for 30 days", such that the next URL the app will
    # redirect to after signing in with email and password is the SP redirect
    # URI.
    user = user_with_2fa
    sign_in_user(user)
    check :remember_device
    fill_in_code_with_last_phone_otp
    click_submit_default
    first(:link, t('links.sign_out')).click

    IdentityLinker.new(
      user, 'urn:gov:gsa:openidconnect:sp:server'
    ).link_identity(verified_attributes: %w[email])

    visit_idp_from_sp_with_loa1(:oidc)
    request_id = ServiceProviderRequest.last.uuid

    Timecop.travel(Devise.timeout_in + 1.minute) do
      # Simulate being idle on the sign in page long enough for the session to
      # be deleted from Redis, but since Redis doesn't respect Timecop, we need
      # to expire the session manually.
      session_store.send(:destroy_session_from_sid, session_cookie.value)
      # Simulate refreshing the page with JS to avoid a CSRF error
      visit new_user_session_url(request_id: request_id)

      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654/auth/result'))

      fill_in_credentials_and_submit(user.email, user.password)

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end
end
