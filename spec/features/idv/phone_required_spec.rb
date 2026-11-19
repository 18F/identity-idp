require 'rails_helper'

RSpec.feature 'NDS U.S. phone number required' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:ab_test_bucket)
      .and_call_original
    allow_any_instance_of(ApplicationController)
      .to receive(:ab_test_bucket)
      .with(:NDS_LOOK_AND_FEEL, any_args)
      .and_return(:nds)

    sign_in_and_2fa_user
    visit idv_welcome_path
    check 'doc_auth_idv_consent_given'
    click_on t('doc_auth.buttons.continue')
    choose t('nds.choose_id_type.option_drivers_license')
    click_on t('doc_auth.buttons.continue')
  end

  context 'when the user enters a non-U.S. number on hybrid handoff' do
    scenario 'stops at the phone required page without sending a link' do
      expect(page).to have_current_path(idv_hybrid_handoff_path)
      expect(Telephony).not_to receive(:send_doc_auth_link)

      fill_in :doc_auth_phone, with: '+44 20 7946 0958'
      click_send_link

      expect(page).to have_current_path(idv_phone_required_path)
      expect(page).to have_css('h1', text: t('nds.phone_required.heading'))
      expect(page).to have_content(t('nds.phone_required.info'))
    end
  end

  context 'when the user enters a U.S. number on hybrid handoff' do
    scenario 'sends the link as before' do
      expect(Telephony).to receive(:send_doc_auth_link)
        .with(hash_including(to: '+1 415-555-0199'))
        .and_call_original

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
    end
  end
end
