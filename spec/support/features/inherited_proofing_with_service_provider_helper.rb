require_relative 'idv_step_helper'
require_relative 'doc_auth_helper'

module InheritedProofingWithServiceProviderHelper
  include IdvStepHelper
  include DocAuthHelper

  # Simulates a user (in this case, a VA inherited proofing-authorized user)
  # coming over to login.gov from a service provider, and hitting the
  # OpenidConnect::AuthorizationController#index action.
  def send_user_from_service_provider_to_login_gov_openid_connect(user, inherited_proofing_auth)
    expect(user).to_not be_nil
    # NOTE: VA user.
    visit_idp_from_oidc_va_with_ial2 inherited_proofing_auth: inherited_proofing_auth
  end

  def complete_steps_up_to_inherited_proofing_get_started_step(user, expect_accessible: false)
    unless current_path == idv_inherited_proofing_step_path(step: :get_started)
      complete_idv_steps_before_phone_step(user)
      click_link t('links.cancel')
      click_button t('idv.cancel.actions.start_over')
      expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :get_started))
    end
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_steps_up_to_inherited_proofing_how_verifying_step(user, expect_accessible: false)
    complete_steps_up_to_inherited_proofing_get_started_step user,
                                                             expect_accessible: expect_accessible
    unless current_path == idv_inherited_proofing_step_path(step: :agreement)
      click_on t('inherited_proofing.buttons.continue')
    end
  end

  def complete_steps_up_to_inherited_proofing_we_are_retrieving_step(user,
                                                                     expect_accessible: false)
    complete_steps_up_to_inherited_proofing_how_verifying_step(
      user,
      expect_accessible: expect_accessible,
    )
    unless current_path == idv_inherited_proofing_step_path(step: :verify_wait)
      check t('inherited_proofing.instructions.consent', app_name: APP_NAME),
            allow_label_click: true
      click_on t('inherited_proofing.buttons.continue')
    end
  end

  def complete_steps_up_to_inherited_proofing_verify_your_info_step(user,
                                                                    expect_accessible: false)
    complete_steps_up_to_inherited_proofing_we_are_retrieving_step(
      user,
      expect_accessible: expect_accessible,
    )
  end
end
