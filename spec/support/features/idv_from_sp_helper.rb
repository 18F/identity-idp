module IdvFromSpHelper
  def self.included(base)
    base.class_eval do
      include IdvHelper
      include JavascriptDriverHelper
      include SamlAuthHelper
    end
  end

  def create_ial2_user_from_sp(email, **options)
    visit_idp_from_sp_with_ial2(:oidc, **options)
    register_user_with_authenticator_app(email)
    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: password
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue
  end

  def reproof_for_ial2_strict
    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: password
    click_continue
    acknowledge_and_confirm_personal_key
  end

  def create_ial1_user_from_sp(email)
    visit_idp_from_sp_with_ial1(:oidc)
    register_user(email)
    click_agree_and_continue
  end

  def create_ial1_user_directly(email)
    visit root_path
    register_user(email)
  end
end
