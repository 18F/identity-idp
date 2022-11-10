require_relative 'idv_step_helper'
require_relative 'doc_auth_helper'

module InheritedProofingHelper
  include IdvStepHelper
  include DocAuthHelper

  # Steps
  def idv_ip_get_started_step
    idv_inherited_proofing_step_path(step: :get_started)
  end

  def idv_inherited_proofing_agreement_step
    idv_inherited_proofing_step_path(step: :agreement)
  end

  def idv_ip_verify_info_step
    idv_inherited_proofing_step_path(step: :verify_info)
  end

  # Traverse Steps

  # create account
  def complete_inherited_proofing_steps_before_get_started_step(expect_accessible: false)
    visit idv_ip_get_started_step unless current_path == idv_ip_get_started_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  # get started
  def complete_get_started_step
    click_on t('inherited_proofing.buttons.continue')
  end

  def complete_inherited_proofing_steps_before_agreement_step(expect_accessible: false)
    complete_inherited_proofing_steps_before_get_started_step(expect_accessible: expect_accessible)
    complete_get_started_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  # get started > agreement > verify_wait > please verify
  def complete_inherited_proofing_steps_before_verify_step(expect_accessible: false)
    complete_inherited_proofing_steps_before_agreement_step(expect_accessible: expect_accessible)
    complete_agreement_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_inherited_proofing_verify_step
    click_on t('inherited_proofing.buttons.continue')
  end

  # get_started > agreement > verify_wait > please verify > complete
  def complete_inherited_proofing_verify_step
    click_on t('inherited_proofing.buttons.continue')
  end

  def complete_all_inherited_proofing_steps_to_handoff(expect_accessible: false)
    complete_inherited_proofing_steps_before_verify_step(expect_accessible: expect_accessible)
    complete_inherited_proofing_verify_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end
end
