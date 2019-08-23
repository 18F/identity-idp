require 'rails_helper'

feature 'use cac step' do
  include CacProofingHelper
  include DocAuthHelper

  let(:use_cac_content) do
    strip_tags(t('doc_auth.info.use_cac_html', link: t('doc_auth.info.use_cac_link')))
  end

  it 'shows cac proofing option if cac proofing is enabled' do
    enable_cac_proofing
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_upload_step

    expect(page).to have_content use_cac_content

    click_link t('doc_auth.info.use_cac_link')
    expect(page).to have_current_path(idv_cac_proofing_welcome_step)
  end

  it 'does not show cac proofing option if cac proofing is disabled' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_upload_step

    expect(page).to_not have_content use_cac_content
  end
end
