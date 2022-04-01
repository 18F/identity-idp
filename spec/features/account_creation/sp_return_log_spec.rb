require 'rails_helper'

feature 'SP return logs' do
  include SamlAuthHelper

  let(:email) { 'test@test.com' }

  it 'creates return log after registration and SP return', :email do
    visit_idp_from_sp_with_ial1(:oidc)
    user = register_user(email)
    click_agree_and_continue

    expect(SpReturnLog.count).to eq(1)
    expect(SpReturnLog.first.user_id).to eq(user.id)
  end
end
