# frozen_string_literal: true

module NDS
  # Net-new NDS account navigation (renders only in the NDS layout): the Home, Account,
  # Security and History items of the signed-in account shell. Emits the
  # .account-nav / .account-nav__* class contract; `mobile: true` adds
  # .account-nav--mobile for the header's mobile menu panel.
  #
  # The current item is `current:` when given, otherwise the item whose section owns the
  # rendering controller (so a sub-page such as manage phone keeps Account marked).
  class AccountNavigationComponent < BaseComponent
    Item = Struct.new(:key, :label, :href, :icon, :current_icon, keyword_init: true)

    SECTION_CONTROLLERS = {
      home: %w[
        accounts/connected_services
        accounts/connected_services/selected_email
        users/service_provider_revoke
        users/sts_consent_revoke
      ],
      account: %w[
        accounts
        accounts/personal_keys
        users/delete
        users/edit_phone
        users/email_language
        users/emails
        users/passwords
      ],
      security: %w[
        accounts/two_factor_authentication
        users/auth_app
        users/piv_cac
        users/webauthn
      ],
      history: %w[
        accounts/history
        events
        users/forget_all_browsers
      ],
    }.freeze

    attr_reader :current, :mobile

    validates :current, inclusion: { in: SECTION_CONTROLLERS.keys }, allow_nil: true

    def initialize(current: nil, mobile: false)
      @current = current.presence&.to_sym
      @mobile = mobile
    end

    def items
      [
        Item.new(
          key: :home,
          label: t('nds.account_nav.home'),
          href: helpers.account_connected_services_path,
          icon: :house,
          current_icon: :house_filled,
        ),
        Item.new(
          key: :account,
          label: t('nds.account_nav.account'),
          href: helpers.account_path,
          icon: :profile_circle,
          current_icon: :profile_circle_filled,
        ),
        Item.new(
          key: :security,
          label: t('nds.account_nav.security'),
          href: helpers.account_two_factor_authentication_path,
          icon: :lock,
          current_icon: :lock_filled,
        ),
        Item.new(
          key: :history,
          label: t('account.navigation.history'),
          href: helpers.account_history_path,
          icon: :clock,
          current_icon: :clock_filled,
        ),
      ]
    end

    def current_key
      current || SECTION_CONTROLLERS.find do |_key, controllers|
        controllers.include?(helpers.controller_path)
      end&.first
    end

    def current?(item)
      item.key == current_key
    end

    def nav_class
      helpers.class_names('account-nav', 'account-nav--mobile': mobile)
    end

    def link_class(item)
      helpers.class_names('account-nav__link', 'account-nav__link--current': current?(item))
    end
  end
end
