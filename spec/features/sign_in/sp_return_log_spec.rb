require 'rails_helper'

feature 'SP return logs' do
  include SamlAuthHelper

  it 'updates user id after user signs in so we can track any user back to issuer', :email do
    user = create(:user, :signed_up)
    visit_idp_from_sp_with_ial1(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)

    expect(SpReturnLog.count).to eq(1)
    expect(SpReturnLog.first.user_id).to eq(user.id)
  end
end
