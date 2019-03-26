require 'rails_helper'

feature 'recovery upload step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

  before do
    enable_doc_auth
    sign_in_before_2fa(user)
    complete_recovery_steps_before_upload_step(user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_upload_step)
    expect(page).to have_content(t('doc_auth.headings.upload'))
  end

  it 'proceeds to the next page' do
    click_on t('doc_auth.buttons.use_computer')
    expect(page).to have_current_path(idv_recovery_front_image_step)
  end
end
