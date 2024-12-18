require 'rails_helper'

RSpec.feature 'a user that is pending verify by mail' do
  include IdvStepHelper

  it 'requires them to enter code or cancel to enter the proofing flow' do
    user = create(:user, :fully_registered)
    profile = create(:profile, :with_pii, :verify_by_mail_pending, user: user)
    create(:gpo_confirmation_code, profile: profile, created_at: 2.days.ago, updated_at: 2.days.ago)

    start_idv_from_sp(facial_match_required: false)
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)

    # Attempting to start IdV should require enter-code to be completed
    visit idv_welcome_path
    expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)

    # Cancelling redirects to IdV flow start
    click_on t('idv.gpo.address_accordion.cta_link')
    click_idv_continue

    expect(page).to have_current_path(idv_welcome_path)
  end

  it 'does not require them to enter their code if they are upgrading to facial match' do
    user = create(:user, :fully_registered)
    profile = create(:profile, :with_pii, :verify_by_mail_pending, user: user)
    create(:gpo_confirmation_code, profile: profile, created_at: 2.days.ago, updated_at: 2.days.ago)

    start_idv_from_sp(facial_match_required: true)
    sign_in_live_with_2fa(user)

    # The user is redirected to proofing since their pending profile does not meet
    # the facial match comparison requirement
    expect(page).to have_current_path(idv_welcome_path)
  end
end
