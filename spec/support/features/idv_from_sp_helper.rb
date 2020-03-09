module IdvFromSpHelper
  def self.included(base)
    base.class_eval do
      include IdvHelper
      include JavascriptDriverHelper
      include SamlAuthHelper
    end
  end

  def create_ial2_user_from_sp(email)
    visit_idp_from_sp_with_ial2(:oidc)
    register_user(email)
    complete_all_doc_auth_steps
    click_continue
    fill_in 'Password', with: password
    click_continue
    click_acknowledge_personal_key
    click_agree_and_continue
  end

  def create_ial1_user_from_sp(email)
    visit_idp_from_sp_with_ial1(:oidc)
    register_user(email)
    click_on t('sign_up.agree_and_continue')
  end

  def create_ial1_user_directly(email)
    visit root_path
    register_user(email)
  end
end
