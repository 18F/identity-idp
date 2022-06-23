require 'rails_helper'

feature 'SP Costing', :email do
  include SpAuthHelper
  include SamlAuthHelper
  include IdvHelper
  include DocAuthHelper
  include IdvFromSpHelper

  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:agency_id) { 2 }
  let(:email) { 'test@test.com' }
  let(:password) { Features::SessionHelper::VALID_PASSWORD }

  it 'logs the correct costs for an ial2 user creation from sp with oidc', js: true do
    create_ial2_user_from_sp(email)

    expect_sp_cost_type(0, 2, 'acuant_front_image')
    expect_sp_cost_type(1, 2, 'acuant_back_image')
    expect_sp_cost_type(2, 2, 'acuant_result')
    expect_sp_cost_type(
      3, 2, 'lexis_nexis_resolution',
      transaction_id: Proofing::Mock::ResolutionMockClient::TRANSACTION_ID
    )
    expect_sp_cost_type(
      4, 2, 'aamva',
      transaction_id: Proofing::Mock::StateIdMockClient::TRANSACTION_ID
    )
    expect_sp_cost_type(5, 2, 'lexis_nexis_address')
  end

  it 'logs the cost to the SP for reproofing', js: true do
    create_ial2_user_from_sp(email)

    # track costs without dealing with 'remember device'
    Capybara.reset_session!

    user = User.find_with_email(email)
    user.active_profile.update!(verified_at: 60.days.ago)

    visit_idp_from_sp_with_ial2(:oidc, verified_within: '45d')
    fill_in_credentials_and_submit(user.confirmed_email_addresses.first.email, password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    complete_all_doc_auth_steps
    click_idv_continue
    fill_in 'Password', with: password
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue

    %w[
      acuant_front_image
      acuant_back_image
      lexis_nexis_resolution
      lexis_nexis_address
    ].each do |cost_type|
      sp_costs = SpCost.where(cost_type: cost_type)
      expect(sp_costs.count).to eq(2)
      sp_costs.each do |sp_cost|
        expect(sp_cost.ial).to eq(2)
        expect(sp_cost.issuer).to eq(issuer)
        expect(sp_cost.agency_id).to eq(agency_id)
      end
    end
  end

  def expect_sp_cost_type(sp_cost_index, ial, token, transaction_id: nil)
    sp_cost = sp_costs(sp_cost_index)
    expect(sp_cost.ial).to eq(ial)
    expect(sp_cost.issuer).to eq(issuer)
    expect(sp_cost.agency_id).to eq(agency_id)
    expect(sp_cost.cost_type).to eq(token)
    expect(sp_cost.transaction_id).to(eq(transaction_id)) if transaction_id
  end

  def sp_costs(index)
    SpCost.order('id asc')[index]
  end
end
