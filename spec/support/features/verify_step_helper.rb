module VerifyStepHelper
  include InPersonHelper

  def expect_good_state_id_address
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_ADDRESS2)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_CITY)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction])
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_ZIPCODE)
  end
end
