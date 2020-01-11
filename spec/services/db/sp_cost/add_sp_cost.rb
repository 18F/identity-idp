require 'rails_helper'

feature 'SP Costing' do
  include SpAuthHelper
  include SamlAuthHelper
  include IdvHelper
  include DocAuthHelper

  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:agency_id) { 2 }

  it 'logs the correct costs for an ial1 user creation from sp with oidc' do
    visit_idp_from_sp_with_ial1(:oidc)
    register_user
    click_on t('forms.buttons.continue')

    expect_cost_type(1, 'sms')
    expect_cost_type(2, 'ial1_user_added')
    expect_cost_type(3, 'authentication')
  end

  it 'logs the correct costs for an ial2 user creation from sp with oidc' do
    visit_idp_from_sp_with_ial2(:oidc)
    register_user
    complete_all_doc_auth_steps
    click_continue
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_continue
    click_acknowledge_personal_key
    click_continue

    expect_cost_type(1, 'sms')
    expect_cost_type(2, 'acuant_front_image')
    expect_cost_type(3, 'acuant_back_image')
    expect_cost_type(4, 'lexis_nexis_resolution')
    expect_cost_type(5, 'ial2_user_added')
    expect_cost_type(6, 'authentication')
  end

  def expect_cost_type(sp_cost_index, token)
    sp_cost = SpCost.find(sp_cost_index)
    expect(sp_cost.issuer).to eq(issuer)
    expect(sp_cost.agency_id).to eq(agency_id)
    expect(sp_cost.cost_type).to eq(token)
  end
end
