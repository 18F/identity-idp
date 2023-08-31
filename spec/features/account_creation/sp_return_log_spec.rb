require 'rails_helper'

RSpec.feature 'SP return logs' do
  include SamlAuthHelper

  let(:email) { 'test@test.com' }

  it 'creates return log after registration and SP return', :email do
    visit_idp_from_sp_with_ial1(:oidc)
    user = register_user(email)
    click_agree_and_continue

    sp_return_log = SpReturnLog.first
    expect(SpReturnLog.count).to eq(1)
    expect(sp_return_log.user_id).to eq(user.id)
    expect(sp_return_log.requested_at).to_not be_nil
  end
end
