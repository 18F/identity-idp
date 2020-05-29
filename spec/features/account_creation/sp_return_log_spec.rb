require 'rails_helper'

feature 'SP return logs' do
  include SamlAuthHelper

  let(:email) { 'test@test.com' }

  it 'updates user id after registration to allow tracking user back to issuer', :email do
    visit_idp_from_sp_with_ial1(:oidc)
    expect(SpReturnLog.count).to eq(1)
    expect(SpReturnLog.first.user_id).to be_nil

    user = register_user(email)

    expect(SpReturnLog.count).to eq(1)
    expect(SpReturnLog.first.user_id).to eq(user.id)
  end
end
