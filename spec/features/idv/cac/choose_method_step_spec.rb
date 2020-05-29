require 'rails_helper'

feature 'cac proofing choose method step' do
  include CacProofingHelper
  include DocAuthHelper

  let(:user) { user_with_2fa }
  before do
    sign_in_and_2fa_user(user)
    complete_cac_proofing_steps_before_choose_method_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_cac_proofing_choose_method_step)
  end

  it 'has a link to doc auth' do
    expect(page).to have_link(t('cac_proofing.buttons.use_doc_auth'), href: idv_doc_auth_path)
  end

  it 'does not visit cac proofing when user has no .gov or .mil email' do
    visit idv_url

    expect(page).to have_current_path(idv_doc_auth_welcome_step)
  end

  it 'does visit directly when user has .mil email' do
    EmailAddress.create(user_id: user.id, email: 'foo@bar.mil')
    visit idv_url

    expect(page).to have_current_path(idv_cac_proofing_choose_method_step)
  end

  it 'does visit directly when user has .gov email' do
    EmailAddress.create(user_id: user.id, email: 'foo@bar.gov')
    visit idv_url

    expect(page).to have_current_path(idv_cac_proofing_choose_method_step)
  end

  it 'visits directly when a user has a cac' do
    ::PivCacConfiguration.create!(user_id: user.id, x509_dn_uuid: 'foo', name: 'key1')
    visit idv_url

    expect(page).to have_current_path(idv_cac_proofing_choose_method_step)
  end
end
