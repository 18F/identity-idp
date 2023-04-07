require 'rails_helper'

feature 'doc auth verify step', :js do
  include IdvStepHelper
  include DocAuthHelper

  let(:puerto_rico_guidance_text) do
    t('doc_auth.info.address_guidance_puerto_rico_html').gsub('<br>', "\n")
  end

  let(:puerto_rico_address1_hint) do
    "#{t('forms.example')} 150 Calle A Apt 3"
  end

  let(:puerto_rico_address2_hint) do
    "#{t('forms.example')} URB Las Gladiolas"
  end

  let(:puerto_rico_city_hint) do
    "#{t('forms.example')} San Juan"
  end

  let(:puerto_rico_zipcode_hint) do
    "#{t('forms.example')} 00926"
  end


  context 'with a mainland address' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_address_step
    end

    it 'does not show the Puerto Rico guidance and hint fields' do
      expect(page).not_to have_content(puerto_rico_guidance_text)
      expect(page).not_to have_content(puerto_rico_address1_hint)
      expect(page).not_to have_content(puerto_rico_address2_hint)
      expect(page).not_to have_content(puerto_rico_city_hint)
      expect(page).not_to have_content(puerto_rico_zipcode_hint)
    end

    context 'that gets changed to a Puerto Rico address' do
      before do
        binding.pry
        select 'Puerto Rico', from: 'idv_form_state'
      end

      it 'shows the Puerto Rico address guidance' do
        binding.pry
        expect(page).to have_content(puerto_rico_guidance_text)
        expect(page).to have_content(puerto_rico_address1_hint)
        expect(page).to have_content(puerto_rico_address2_hint)
        expect(page).to have_content(puerto_rico_city_hint)
        expect(page).to have_content(puerto_rico_zipcode_hint)
      end
    end

    it 'allows the user to enter in a new address' do
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).not_to have_content(t('forms.example'))
      fill_out_address_form_ok

      click_button t('forms.buttons.submit.update')
      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'does not allow the user to enter bad address info' do
      fill_out_address_form_fail

      click_button t('forms.buttons.submit.update')
      expect(page).to have_current_path(idv_address_path)
    end

    it 'allows the user to click back to return to the verify step' do
      click_doc_auth_back_link

      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'sends the user to start doc auth if there is no pii from the document in session' do
      visit sign_out_url
      sign_in_and_2fa_user
      visit idv_address_path

      expect(page).to have_current_path(idv_doc_auth_welcome_step)
    end
  end

  context 'with a Puerto Rico address' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_document_capture_step
      complete_document_capture_step_with_yml('spec/fixtures/puerto_rico_resident.yml')
      complete_ssn_step
    end

    it 'renders the Puerto Rico address guidance as visible text' do
      guidance = page.find_by_id('puerto-rico-extra-text')

      expect(guidance.text).to include(puerto_rico_guidance_text)
      expect(guidance).to be_visible
    end

    it 'accepts a Puerto Rico style address' do
      expect(page).to have_current_path(idv_address_url)
      expect(page).to have_content(t('forms.example'))
      fill_in 'idv_form_address1', with: '123 Calle Carlos'
      fill_in 'idv_form_address2', with: 'URB Las Gladiolas'
      click_button t('forms.buttons.submit.update')
      expect(page).to have_current_path(idv_verify_info_path)
    end

    context 'that gets changed to a mainland address' do
      before do
        select 'Wyoming', from: 'idv_form_state'
      end

      it 'hides the Puerto Rico address guidance' do
        guidance = page.find_by_id('puerto-rico-extra-text', visible: false)

        expect(guidance).not_to be_visible
      end
    end
  end

  context 'with document capture controller flag set, no PII in session' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_document_capture_controller_enabled).
        and_return(true)
      sign_in_and_2fa_user
    end

    it 'goes to new document capture page on standard flow' do
      complete_doc_auth_steps_before_document_capture_step
      visit(idv_address_url)
      expect(page).to have_current_path(idv_document_capture_url)
    end

    it 'stays in FSM on hybrid flow' do
      complete_doc_auth_steps_before_link_sent_step
      visit(idv_address_url)
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    end
  end
end
