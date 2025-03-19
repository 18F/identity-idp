require_relative 'idv_helper'
require_relative 'javascript_driver_helper'
require_relative 'doc_auth_helper'
require_relative '../saml_auth_helper'

module IdvStepHelper
  def self.included(base)
    base.class_eval do
      include IdvHelper
      include JavascriptDriverHelper
      include SamlAuthHelper
      include DocAuthHelper
    end
  end

  def start_idv_from_sp(sp = :oidc, facial_match_required: nil)
    if sp.present?
      visit_idp_from_sp_with_ial2(sp, facial_match_required:)
    else
      visit root_path
    end
  end

  def complete_idv_steps_before_phone_step(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    complete_all_doc_auth_steps
  end

  def complete_phone_step(user)
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    verify_phone_otp
  end

  def enter_gpo_flow
    click_on t('idv.troubleshooting.options.verify_by_mail')
  end

  def complete_idv_steps_before_gpo_step(user = user_with_2fa)
    complete_idv_steps_before_phone_step(user)
    enter_gpo_flow
  end

  def complete_request_letter
    click_on t('idv.buttons.mail.send')
  end

  def complete_idv_steps_before_phone_otp_verification_step(user = user_with_2fa)
    complete_idv_steps_before_phone_step(user)
    fill_out_phone_form_ok('2342255432')
    choose_idv_otp_delivery_method_sms
  end

  def complete_idv_steps_with_phone_before_enter_password_step(user = user_with_2fa)
    complete_idv_steps_before_phone_step(user)
    complete_phone_step(user)
  end

  def visit_help_center
    click_what_to_bring_link
  end

  def click_what_to_bring_link
    expect(page).to have_content(strip_nbsp(t('in_person_proofing.headings.barcode')))
    click_link t('in_person_proofing.body.barcode.learn_more')
  end

  def sp_friendly_name
    'Test SP'
  end

  def link_text
    t('in_person_proofing.body.barcode.return_to_partner_link', sp_name: sp_friendly_name)
  end

  def visit_sp_from_in_person_ready_to_verify
    expect(page).to have_content(link_text)
    click_link(link_text)
  end

  def complete_enter_password_step(user = user_with_2fa)
    password = user.password || user_password
    fill_in 'Password', with: password, wait: 60
    click_idv_continue
  end

  def complete_idv_steps_with_phone_before_confirmation_step(user = user_with_2fa)
    complete_idv_steps_with_phone_before_enter_password_step(user)
    complete_enter_password_step(user)
  end

  alias_method :complete_idv_steps_before_enter_password_step,
               :complete_idv_steps_with_phone_before_enter_password_step

  def complete_idv_steps_with_gpo_before_enter_password_step(user = user_with_2fa)
    complete_idv_steps_before_gpo_step(user)
    complete_request_letter
  end

  def complete_idv_steps_with_gpo_before_confirmation_step(user = user_with_2fa)
    complete_idv_steps_with_gpo_before_enter_password_step(user)
    password = user.password || user_password
    fill_in 'Password', with: password
    click_continue
  end

  def complete_idv_steps_before_step(step, user = user_with_2fa)
    send(:"complete_idv_steps_before_#{step}_step", user)
  end

  def expect_step_indicator_current_step(text)
    expect(page).to have_css('.step-indicator__step--current', text: text, wait: 10)
  end

  def complete_idv_steps_before_address(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    # prepare page
    complete_prepare_step(user)
    # location page
    complete_location_step(user)
    # state ID page
    fill_out_state_id_form_ok(same_address_as_id: false)
    click_idv_continue
  end

  def complete_idv_steps_before_ssn(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    # prepare page
    complete_prepare_step(user)
    # location page
    complete_location_step(user)
    # state ID page
    fill_out_state_id_form_ok(same_address_as_id: true)
    click_idv_continue
  end

  def complete_remote_idv_from_ssn(user = user_with_2fa)
    # ssn step
    expect(page).not_to have_content(t('step_indicator.flows.idv.go_to_the_post_office'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    complete_ssn_step

    # verify step
    expect(page).not_to have_content(t('step_indicator.flows.idv.go_to_the_post_office'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    complete_verify_step

    # verify phone
    expect(page).not_to have_content(t('step_indicator.flows.idv.go_to_the_post_office'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_phone'))
    complete_phone_step(user)

    # re-enter password
    expect(page).not_to have_content(t('step_indicator.flows.idv.go_to_the_post_office'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.re_enter_password'))
    complete_enter_password_step(user)

    # personal key page
    expect(page).not_to have_content(t('step_indicator.flows.idv.go_to_the_post_office'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.re_enter_password'))
    expect(page).to have_current_path(idv_personal_key_url)
    acknowledge_and_confirm_personal_key

    # sign up completed
    expect(page).to have_current_path(sign_up_completed_url)
  end
end
