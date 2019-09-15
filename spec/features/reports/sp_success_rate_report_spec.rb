require 'rails_helper'

feature 'scheduler runs report' do
  include SamlAuthHelper

  it 'works for no users' do
    expect(Reports::SpSuccessRateReport.new.call).to eq([].to_json)
  end

  it 'works for users that have landed from sp and left' do
    visit_idp_from_sp_with_loa1(:oidc)

    results = [{ issuer: 'urn:gov:gsa:openidconnect:sp:server', return_rate: 0.0 }]
    expect(Reports::SpSuccessRateReport.new.call).to eq(results.to_json)
  end

  it 'works for users that have landed from sp signed in and returned to sp' do
    visit_idp_from_sp_and_back_again

    results = [{ issuer: 'urn:gov:gsa:openidconnect:sp:server', return_rate: 1.0 }]
    expect(Reports::SpSuccessRateReport.new.call).to eq(results.to_json)
  end

  def visit_idp_from_sp_and_back_again
    user = create(:user, :signed_up)
    visit_idp_from_sp_with_loa1(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    click_continue
  end
end
