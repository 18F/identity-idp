require 'rails_helper'

feature 'SP Costing' do
  include SpAuthHelper
  include SamlAuthHelper

  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:agency_id) { 2 }

  it 'logs the correct costs for an ial1 user creation from sp with oidc' do
    visit_idp_from_sp_with_ial1(:oidc)
    register_user
    click_on t('forms.buttons.continue')

    expect(SpCost.count).to eq(3)
    expect_cost_type(SpCost.find(1), 'sms')
    expect_cost_type(SpCost.find(2), 'ial1_user_added')
    expect_cost_type(SpCost.find(3), 'authentication')
  end

  def expect_cost_type(sp_cost, token)
    expect(sp_cost.issuer).to eq(issuer)
    expect(sp_cost.agency_id).to eq(agency_id)
    expect(sp_cost.cost_type).to eq(token)
  end
end
