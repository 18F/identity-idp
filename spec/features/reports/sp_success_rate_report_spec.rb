require 'rails_helper'

feature 'scheduler runs report' do
  include SamlAuthHelper

  it 'works for no users' do
    expect(Reports::SpSuccessRateReport.new.call).to eq([].to_json)
  end

  it 'works for users that have landed but not signed in' do
    visit_idp_from_sp_with_loa1(:oidc)

    results = [{issuer: 'urn:gov:gsa:openidconnect:sp:server', return_rate: 0.0}]
    expect(Reports::SpSuccessRateReport.new.call).to eq(results.to_json)
  end
end
