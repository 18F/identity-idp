class Navigation
  include Rails.application.routes.url_helpers

  NavItem = Struct.new(:title, :href, :children)

  def initialize(user:, url_options:)
    @user = user
    @url_options = url_options
  end

  def navigation_items
    [
      NavItem.new(
        I18n.t('account.navigation.your_account'), account_path, [
          NavItem.new(I18n.t('account.navigation.add_email'), add_email_path),
          NavItem.new(I18n.t('account.navigation.edit_password'), manage_password_path),
          NavItem.new(I18n.t('account.navigation.delete_account'), account_delete_path),
        ]
      ),
      NavItem.new(
        I18n.t('account.navigation.two_factor_authentication'),
        account_two_factor_authentication_path, [
          NavItem.new(I18n.t('account.navigation.add_phone_number'), add_phone_path),
          NavItem.new(
            I18n.t('account.navigation.add_authentication_apps'),
            authenticator_setup_url,
          ),
          NavItem.new(I18n.t('account.navigation.add_security_key'), webauthn_setup_path),
          NavItem.new(I18n.t('account.navigation.add_federal_id'), setup_piv_cac_path),
          NavItem.new(
            I18n.t('account.navigation.get_backup_codes'),
            backup_codes_path,
          ),
        ]
      ),
      NavItem.new(
        I18n.t('account.navigation.connected_accounts'),
        account_connected_accounts_path, []
      ),
      NavItem.new(
        I18n.t('account.navigation.history'), account_history_path, [
          NavItem.new(
            I18n.t('account.navigation.forget_browsers'),
            forget_all_browsers_path,
          ),
        ]
      ),
      NavItem.new(I18n.t('account.navigation.customer_support'), MarketingSite.help_url, []),
    ]
  end

  def url_options
    @url_options
  end

  def backup_codes_path
    if TwoFactorAuthentication::BackupCodePolicy.new(@user).configured?
      backup_code_regenerate_path
    else
      backup_code_create_path
    end
  end
end
