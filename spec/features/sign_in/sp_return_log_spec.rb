require 'rails_helper'

RSpec.feature 'SP return logs' do
  include SamlAuthHelper

  it 'updates user id after user authenticates so we can track any user back to issuer', :email do
    user = create(:user, :with_phone)
    visit_idp_from_sp_with_ial1(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)
    click_button t('forms.buttons.submit.default')
    fill_in 'code', with: user.reload.direct_otp
    click_button t('forms.buttons.submit.default')
    click_agree_and_continue

    expect(SpReturnLog.count).to eq(1)
    expect(SpReturnLog.first.user_id).to eq(user.id)
  end
end
