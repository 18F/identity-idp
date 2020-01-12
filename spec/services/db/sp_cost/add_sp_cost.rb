require 'rails_helper'

feature 'SP Costing' do
  include SpAuthHelper
  include SamlAuthHelper
  include IdvHelper
  include DocAuthHelper

  before do
    enable_doc_auth
  end

  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:agency_id) { 2 }
  let(:email1) { 'test@test.com' }
  let(:email2) { 'test2@test.com' }
  let(:email3) { 'test3@test.com' }
  let(:password) { Features::SessionHelper::VALID_PASSWORD }

  it 'logs the correct costs for an ial1 user creation from sp with oidc' do
    create_ial1_user_from_sp(email1)

    expect_cost_type(0, 'sms')
    expect_cost_type(1, 'ial1_user_added')
    expect_cost_type(2, 'authentication')
  end

  it 'logs the correct costs for an ial2 user creation from sp with oidc' do
    create_ial2_user_from_sp(email2)

    expect_cost_type(0, 'sms')
    expect_cost_type(1, 'acuant_front_image')
    expect_cost_type(2, 'acuant_back_image')
    expect_cost_type(3, 'lexis_nexis_resolution')
    expect_cost_type(4, 'ial2_user_added')
    expect_cost_type(5, 'authentication')
  end

  it 'logs the correct costs for an ial2 authentication' do
    create_ial2_user_from_sp(email3)
    SpCost.delete_all
    Capybara.reset_session!

    visit_idp_from_sp_with_ial2(:oidc)
    fill_in_credentials_and_submit(email3, password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect_cost_type(0, 'digest')
  end

  def create_ial1_user_from_sp(email)
    visit_idp_from_sp_with_ial1(:oidc)
    register_user(email)
    click_on t('forms.buttons.continue')
  end

  def create_ial2_user_from_sp(email)
    visit_idp_from_sp_with_ial2(:oidc)
    register_user(email)
    complete_all_doc_auth_steps
    click_continue
    fill_in 'Password', with: password
    click_continue
    click_acknowledge_personal_key
    click_continue
  end

  def expect_cost_type(sp_cost_index, token)
    sp_cost = sp_costs(sp_cost_index)
    expect(sp_cost.issuer).to eq(issuer)
    expect(sp_cost.agency_id).to eq(agency_id)
    expect(sp_cost.cost_type).to eq(token)
  end

  def sp_costs(index)
    SpCost.order('id asc')[index]
  end
end
