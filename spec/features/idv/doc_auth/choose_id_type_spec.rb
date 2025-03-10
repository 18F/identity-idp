require 'rails_helper'

RSpec.feature 'choose id type step error checking' do
  include DocAuthHelper
  context 'desktop flow', :js do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    it 'shows choose id type screen and continues after passport option' do
      expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
      click_on t('forms.buttons.upload_photos')
      expect(page).to have_current_path(idv_choose_id_type_url)
      choose(t('doc_auth.forms.id_type_preference.passport'))
      click_on t('forms.buttons.continue')
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end
  context 'mobile flow', :js, driver: :headless_chrome_mobile do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'shows choose id type screen and continues after drivers license option' do
      expect(page).to have_current_path(idv_choose_id_type_url)
      choose(t('doc_auth.forms.id_type_preference.drivers_license'))
      click_on t('forms.buttons.continue')
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end
end
