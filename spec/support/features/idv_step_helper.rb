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

  def start_idv_from_sp(sp = :oidc)
    if sp.present?
      visit_idp_from_sp_with_ial2(sp)
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

  def gpo_step
    click_on t('idv.buttons.mail.send')
  end

  def complete_idv_steps_before_phone_otp_verification_step(user = user_with_2fa)
    complete_idv_steps_before_phone_step(user)
    fill_out_phone_form_ok('2342255432')
    choose_idv_otp_delivery_method_sms
  end

  def complete_idv_steps_with_phone_before_review_step(user = user_with_2fa)
    complete_idv_steps_before_phone_step(user)
    complete_phone_step(user)
  end

  def complete_review_step(user = user_with_2fa)
    password = user.password || user_password
    fill_in 'Password', with: password
    click_idv_continue
  end

  def complete_idv_steps_with_phone_before_confirmation_step(user = user_with_2fa)
    complete_idv_steps_with_phone_before_review_step(user)
    complete_review_step(user)
  end

  alias complete_idv_steps_before_review_step complete_idv_steps_with_phone_before_review_step

  def complete_idv_steps_with_gpo_before_review_step(user = user_with_2fa)
    complete_idv_steps_before_gpo_step(user)
    gpo_step
  end

  def complete_idv_steps_with_gpo_before_confirmation_step(user = user_with_2fa)
    complete_idv_steps_with_gpo_before_review_step(user)
    password = user.password || user_password
    fill_in 'Password', with: password
    click_continue
  end

  def complete_idv_steps_before_confirmation_step(address_verification_mechanism = :phone)
    if address_verification_mechanism == :phone
      complete_idv_steps_with_phone_before_confirmation_step
    else
      complete_idv_steps_with_gpo_before_confirmation_step
    end
  end

  def complete_idv_steps_before_step(step, user = user_with_2fa)
    send("complete_idv_steps_before_#{step}_step", user)
  end

  def expect_step_indicator_current_step(text)
    expect(page).to have_css('.step-indicator__step--current', text: text)
  end

  private

  def stub_idv_session(**session_attributes)
    allow(Idv::Session).to receive(:new).and_wrap_original do |original, kwargs|
      result = original.call(**kwargs)
      kwargs[:user_session][:idv].merge!(session_attributes)
      result
    end
  end
end
