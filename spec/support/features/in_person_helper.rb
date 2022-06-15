module InPersonHelper
  GOOD_FIRST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
  GOOD_LAST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:last_name]
  GOOD_DOB = Idp::Constants::MOCK_IDV_APPLICANT[:dob]
  GOOD_STATE_ID_JURISDICTION = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION
  GOOD_STATE_ID_NUMBER = Idp::Constants::MOCK_IDV_APPLICANT[:state_id_number]

  def fill_out_state_id_form_ok
    fill_in t('in_person_proofing.form.state_id.first_name'), with: GOOD_FIRST_NAME
    fill_in t('in_person_proofing.form.state_id.last_name'), with: GOOD_LAST_NAME
    year, month, day = GOOD_DOB.split('-')
    fill_in t('in_person_proofing.form.state_id.dob'), with: [month, day, year].join('-')
    select GOOD_STATE_ID_JURISDICTION,
           from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
    fill_in t('in_person_proofing.form.state_id.state_id_number'), with: GOOD_STATE_ID_NUMBER
  end
end
