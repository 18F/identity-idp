# frozen_string_literal: true

class NavigationPresenter
  include Rails.application.routes.url_helpers

  NavItem = Struct.new(:title, :href, :icon)

  attr_reader :url_options

  def initialize(url_options:)
    @url_options = url_options
  end

  def navigation_items
    [
      NavItem.new(I18n.t('account.navigation.home'), account_path, :house),
      NavItem.new(
        I18n.t('account.navigation.profile'),
        account_settings_path,
        :profile_circle,
      ),
      NavItem.new(I18n.t('account.navigation.security'), account_security_path, :lock),
      NavItem.new(I18n.t('account.navigation.history'), account_history_path, :clock),
    ]
  end
end
