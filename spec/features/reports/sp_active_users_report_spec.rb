require 'rails_helper'

feature 'sp active users report' do
  include SamlAuthHelper
  include IdvHelper

  it 'reports a user as ial1 active for an ial1 sign in' do
    user = create(:user, :signed_up)
    visit_idp_from_sp_with_ial1(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    click_agree_and_continue
    expect(current_url).to start_with('http://localhost:7654/auth/result')

    results = [{ issuer: 'urn:gov:gsa:openidconnect:sp:server',
                 app_id: nil,
                 total_ial1_active: 1,
                 total_ial2_active: 0 }].to_json
    expect(Db::Identity::SpActiveUserCounts.call('01-01-2019').to_json).to eq(results)
  end

  it 'reports a user as ial2 active for an ial2 sign in' do
    user = create(
      :profile,
      :active,
      :verified,
      pii: { first_name: 'John', ssn: '111223333' },
    ).user
    visit_idp_from_sp_with_ial2(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    click_agree_and_continue
    expect(current_url).to start_with('http://localhost:7654/auth/result')

    results = [{ issuer: 'urn:gov:gsa:openidconnect:sp:server',
                 app_id: nil,
                 total_ial1_active: 0,
                 total_ial2_active: 1 }].to_json
    expect(Db::Identity::SpActiveUserCounts.call('01-01-2019').to_json).to eq(results)
  end
end
