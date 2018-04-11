require 'rails_helper'

feature 'IdV max attempts', :idv_job, :email do
  include IdvStepHelper
  include JavascriptDriverHelper

  let(:user) { user_with_2fa }

  before do
    visit_idp_from_sp_with_loa3(:oidc)
    click_link t('links.sign_in')
  end

  context 'profile step' do
    before do
      start_idv_at_profile_step(user)
      perfom_maximum_allowed_idv_step_attempts { fill_out_idv_form_fail }
    end

    it_behaves_like 'verification step max attempts', :sessions
  end

  context 'phone step' do
    before do
      complete_idv_steps_before_phone_step
      perfom_maximum_allowed_idv_step_attempts { fill_out_phone_form_fail }
    end

    it_behaves_like 'verification step max attempts', :phone
  end

  def perfom_maximum_allowed_idv_step_attempts(&fill_out_form_fail_block)
    max_attempts_less_one.times do
      fill_out_form_fail_block.call
      click_idv_continue
      click_button t('idv.modal.button.warning') if javascript_enabled?
    end
    fill_out_form_fail_block.call
    click_idv_continue
  end
end
