# frozen_string_literal: true

class TwoFactorLoginOptionsPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
  include DestructiveAccountResetConcern
  include ActionView::Helpers::TranslationHelper

  NDSOption = Data.define(:option, :icon, :title, :description)

  NDS_OPTION_RANKS = {
    'webauthn_platform' => 0,
    'sms' => 1,
    'voice' => 1,
    'phone' => 1,
    'auth_app' => 2,
    'webauthn' => 3,
    'backup_code' => 4,
    'piv_cac' => 5,
    'personal_key' => 6,
  }.freeze

  NDS_OPTION_ICONS = {
    'webauthn_platform' => :fingerprint,
    'sms' => :chat,
    'voice' => :chat,
    'phone' => :chat,
    'auth_app' => :qr,
    'webauthn' => :key,
    'backup_code' => :download_backup,
    'piv_cac' => :id,
    'personal_key' => :qr,
  }.freeze

  attr_reader :user,
              :reauthentication_context,
              :phishing_resistant_required,
              :piv_cac_required,
              :add_piv_cac_after_2fa

  alias_method :reauthentication_context?, :reauthentication_context
  alias_method :phishing_resistant_required?, :phishing_resistant_required
  alias_method :piv_cac_required?, :piv_cac_required
  alias_method :add_piv_cac_after_2fa?, :add_piv_cac_after_2fa

  def initialize(
    user:,
    view:,
    reauthentication_context:,
    service_provider:,
    phishing_resistant_required:,
    piv_cac_required:,
    add_piv_cac_after_2fa:
  )
    @user = user
    @view = view
    @reauthentication_context = reauthentication_context
    @service_provider = service_provider
    @phishing_resistant_required = phishing_resistant_required
    @piv_cac_required = piv_cac_required
    @add_piv_cac_after_2fa = add_piv_cac_after_2fa
  end

  def title
    t('two_factor_authentication.login_options_title')
  end

  def heading
    if reauthentication_context?
      t('two_factor_authentication.login_options_reauthentication_title')
    else
      t('two_factor_authentication.login_options_title')
    end
  end

  def info
    if reauthentication_context?
      t('two_factor_authentication.login_intro_reauthentication')
    else
      t('two_factor_authentication.login_intro')
    end
  end

  def restricted_options_warning_text
    return if show_all_options?

    if piv_cac_required?
      t('two_factor_authentication.aal2_request.piv_cac_only_html', sp_name:)
    elsif phishing_resistant_required?
      t('two_factor_authentication.aal2_request.phishing_resistant_html', sp_name:)
    end
  end

  def options
    return @options if defined?(@options)
    mfa = MfaContext.new(user)

    if piv_cac_required? && !show_all_options?
      configurations = mfa.piv_cac_configurations
    elsif phishing_resistant_required? && !show_all_options?
      configurations = mfa.phishing_resistant_configurations
    else
      configurations = mfa.two_factor_configurations

      if TwoFactorAuthentication::PersonalKeyPolicy.new(user).enabled? &&
         IdentityConfig.store.personal_key_as_mfa_active
        configurations << mfa.personal_key_configuration
      end
    end
    # A user can have multiples of certain types of MFA methods, such as
    # webauthn keys and phones. However, we only want to show one of each option
    # during login, except for phones, where we want to allow the user to choose
    # which MFA-enabled phone they want to use.
    @options = configurations.group_by(&:class).flat_map do |klass, set|
      klass.selection_presenters(set)
    end
  end

  def account_reset_or_cancel_link
    return account_reset_cancel_link if account_reset_token_valid?
    return unless AccountRecovery::EligibilityPolicy.new(user: user).legacy_reset_allowed?

    account_reset_link
  end

  def account_recovery_pending?
    AccountRecovery::EligibilityPolicy.new(user: user).recovery_pending?
  end

  def account_recovery_eligible?
    return @account_recovery_eligible if defined?(@account_recovery_eligible)

    @account_recovery_eligible = AccountRecovery::EligibilityPolicy.new(
      user: user,
    ).eligible?
  end

  def account_recovery_link
    t(
      'two_factor_authentication.account_recovery.recover_text_html',
      link_html: @view.link_to(
        t('two_factor_authentication.account_recovery.recover_link'),
        account_recovery_start_path(locale: LinkLocaleResolver.locale),
      ),
    )
  end

  def cancel_link
    if reauthentication_context?
      account_path
    else
      sign_out_path
    end
  end

  def first_enabled_option_index
    options.find_index { |option| !option.disabled? } || 0
  end

  def nds_options
    options.each_with_index
      .sort_by { |option, index| [nds_rank(option), index] }
      .map do |option, _index|
        kind = nds_kind(option)
        NDSOption.new(
          option:,
          icon: NDS_OPTION_ICONS.fetch(kind, :lock),
          title: nds_title(option, kind),
          description: nds_description(option, kind),
        )
      end
  end

  private

  def nds_rank(option)
    NDS_OPTION_RANKS.fetch(nds_kind(option), NDS_OPTION_RANKS.length)
  end

  def nds_kind(option)
    option.type.to_s.sub(/_\d+\z/, '')
  end

  def nds_title(option, kind)
    case kind
    when 'webauthn_platform' then t('nds.mfa_setup.options.webauthn_platform')
    when 'personal_key' then t('forms.two_factor.personal_key')
    else option.label
    end
  end

  def nds_description(option, kind)
    case kind
    when 'webauthn_platform' then t('nds.mfa_options.webauthn_platform_info')
    when 'piv_cac' then t('nds.mfa_setup.options.piv_cac_info')
    else option.info
    end
  end

  def show_all_options?
    reauthentication_context? || add_piv_cac_after_2fa? || user_doesnt_have_required_mfa?
  end

  def user_doesnt_have_required_mfa?
    mfa = MfaContext.new(user)
    if (piv_cac_required? && !mfa.piv_cac_configurations.any?) ||
       (phishing_resistant_required? && !mfa.phishing_resistant_configurations.any?)
      return true
    end
  end

  def account_reset_link
    t(
      'two_factor_authentication.account_reset.text_html',
      link_html: @view.link_to(
        t('two_factor_authentication.account_reset.link'),
        account_reset_url(locale: LinkLocaleResolver.locale),
      ),
    )
  end

  def account_reset_url(locale:)
    account_reset_recovery_options_path(locale: locale)
  end

  def account_reset_cancel_link
    safe_join(
      [
        t(
          'two_factor_authentication.account_reset.pending',
          interval: account_reset_deletion_period_interval(user),
        ),
        @view.link_to(
          t('two_factor_authentication.account_reset.cancel_link'),
          account_reset_cancel_url(token: account_reset_token),
        ),
      ],
      ' ',
    )
  end

  def account_reset_token
    user&.account_reset_request&.request_token
  end

  def account_reset_token_valid?
    user&.account_reset_request&.granted_token_valid?
  end

  def sp_name
    if service_provider
      service_provider.friendly_name
    else
      APP_NAME
    end
  end
end
