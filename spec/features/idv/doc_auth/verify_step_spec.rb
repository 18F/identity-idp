require 'rails_helper'

feature 'doc auth verify step' do
  include IdvStepHelper
  include DocAuthHelper
  include InPersonHelper

  let(:max_attempts) { Idv::Attempter.idv_max_attempts }
  before do
    enable_doc_auth
    complete_doc_auth_steps_before_verify_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_verify_step)
    expect(page).to have_content(t('doc_auth.headings.verify'))
  end

  it 'proceeds to the next page upon confirmation' do
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_success_step)
  end

  it 'proceeds to the address page if the user clicks change address' do
    click_link t('doc_auth.buttons.change_address')

    expect(page).to have_current_path(idv_address_path)
  end

  it 'proceeds to the ssn page if the user clicks change ssn' do
    click_button t('doc_auth.buttons.change_ssn')

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'does not proceed to the next page if resolution fails' do
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
  end

  it 'does not proceed to the next page if ssn is a duplicate' do
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    enable_in_person_proofing
    expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
    expect(page).to_not have_link(t('in_person_proofing.opt_in_link'),
                                  href: idv_in_person_welcome_step)
  end

  it 'has a link to proof in person' do
    enable_in_person_proofing
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    expect(page).to have_link(t('in_person_proofing.opt_in_link'),
                              href: idv_in_person_welcome_step)
  end

  it 'throttles resolution' do
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
      visit idv_doc_auth_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_failure_path(reason: :fail))
  end

  it 'throttles dup ssn' do
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
      visit idv_doc_auth_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_failure_path(reason: :fail))
  end
end
