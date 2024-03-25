class NavigationPresenter
  include Rails.application.routes.url_helpers

  NavItem = Struct.new(:title, :href, :children)

  attr_reader :user, :url_options

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
          user.encrypted_recovery_code_digest.present? && user.active_profile ? NavItem.new(
            I18n.t('account.navigation.reset_personal_key'), create_new_personal_key_path
          ) : nil,
        ].compact
      ),
      NavItem.new(
        I18n.t('account.navigation.two_factor_authentication'),
        account_two_factor_authentication_path, [
          NavItem.new(I18n.t('account.navigation.add_phone_number'), phone_setup_path),
          NavItem.new(
            I18n.t('account.navigation.add_authentication_apps'),
            authenticator_setup_url,
          ),
          NavItem.new(
            I18n.t('account.navigation.add_platform_authenticator'),
            webauthn_setup_path(platform: true),
          ),
          NavItem.new(I18n.t('account.navigation.add_security_key'), webauthn_setup_path),
          NavItem.new(I18n.t('account.navigation.add_federal_id'), setup_piv_cac_path),
          NavItem.new(
            I18n.t('account.navigation.get_backup_codes'),
            backup_codes_path,
          ),
        ].compact
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

  def backup_codes_path
    if TwoFactorAuthentication::BackupCodePolicy.new(user).configured?
      backup_code_regenerate_path
    else
      backup_code_setup_path
    end
  end
end
