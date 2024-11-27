module VerifyStepHelper
  include InPersonHelper

  def expect_good_state_id_address
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE)
  end

  def expect_good_address
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).to have_content(t('idv.form.address2'))
    expect(page).to have_text(InPersonHelper::GOOD_CITY)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
    expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
  end
end
