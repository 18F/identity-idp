require 'rails_helper'

RSpec.feature 'choose id type step error checking' do
  include DocAuthHelper
  context 'desktop flow', :js do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    it 'shows choose id type screen after hybrid handoff upload' do
      expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
      click_on t('forms.buttons.upload_photos')
      expect(page).to have_current_path(idv_choose_id_type_url)
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

    it 'shows choose id type screen after agreements' do
      expect(page).to have_current_path(idv_choose_id_type_url)
    end
  end
end
