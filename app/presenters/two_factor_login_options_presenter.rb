class TwoFactorLoginOptionsPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user

  def initialize(
    user:,
    view:,
    user_session_context:,
    service_provider:,
    phishing_resistant_required:,
    piv_cac_required:
  )
    @user = user
    @view = view
    @user_session_context = user_session_context
    @service_provider = service_provider
    @phishing_resistant_required = phishing_resistant_required
    @piv_cac_required = piv_cac_required
  end

  def title
    t('two_factor_authentication.login_options_title')
  end

  def heading
    t('two_factor_authentication.login_options_title')
  end

  def info
    t('two_factor_authentication.login_intro')
  end

  def options
    mfa = MfaContext.new(user)

    if @piv_cac_required
      configurations = mfa.piv_cac_configurations
    elsif @phishing_resistant_required
      configurations = mfa.phishing_resistant_configurations
    else
      configurations = mfa.two_factor_configurations
      # for now, we include the personal key since that's our current behavior,
      # but there are designs to remove personal key from the option list and
      # make it a link with some additional text to call it out as a special
      # case.
      if TwoFactorAuthentication::PersonalKeyPolicy.new(user).enabled?
        configurations << mfa.personal_key_configuration
      end
    end
    # A user can have multiples of certain types of MFA methods, such as
    # webauthn keys and phones. However, we only want to show one of each option
    # during login, except for phones, where we want to allow the user to choose
    # which MFA-enabled phone they want to use.
    configurations.group_by(&:class).flat_map { |klass, set| klass.selection_presenters(set) }
  end

  def account_reset_or_cancel_link
    account_reset_token_valid? ? account_reset_cancel_link : account_reset_link
  end

  def cancel_link
    if UserSessionContext.reauthentication_context?(@user_session_context)
      account_path
    else
      sign_out_path
    end
  end

  def first_enabled_option_index
    options.find_index { |option| !option.disabled? } || 0
  end

  private

  def account_reset_link
    t(
      'two_factor_authentication.account_reset.text_html',
      link: @view.link_to(
        t('two_factor_authentication.account_reset.link'),
        account_reset_url(locale: LinkLocaleResolver.locale),
      ),
    )
  end

  def account_reset_url(locale:)
    IdentityConfig.store.show_account_recovery_recovery_options ?
      account_reset_recovery_options_path(locale: locale) :
        account_reset_request_path(locale: locale)
  end

  def account_reset_cancel_link
    t(
      'two_factor_authentication.account_reset.pending_html',
      cancel_link: @view.link_to(
        t('two_factor_authentication.account_reset.cancel_link'),
        account_reset_cancel_url(token: account_reset_token),
      ),
    )
  end

  def account_reset_token
    user&.account_reset_request&.request_token
  end

  def account_reset_token_valid?
    user&.account_reset_request&.granted_token_valid?
  end
end
