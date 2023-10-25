# frozen_string_literal: true

class TwoFactorLoginOptionsPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :reauthentication_context, :phishing_resistant_required, :piv_cac_required

  alias_method :reauthentication_context?, :reauthentication_context
  alias_method :phishing_resistant_required?, :phishing_resistant_required
  alias_method :piv_cac_required?, :piv_cac_required

  def initialize(
    user:,
    view:,
    reauthentication_context:,
    service_provider:,
    phishing_resistant_required:,
    piv_cac_required:
  )
    @user = user
    @view = view
    @reauthentication_context = reauthentication_context
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

  def restricted_options_warning_text
    return if reauthentication_context?

    if piv_cac_required?
      t('two_factor_authentication.aal2_request.piv_cac_only_html', sp_name:)
    elsif phishing_resistant_required?
      t('two_factor_authentication.aal2_request.phishing_resistant_html', sp_name:)
    end
  end

  def options
    return @options if defined?(@options)
    mfa = MfaContext.new(user)

    if piv_cac_required? && !reauthentication_context?
      configurations = mfa.piv_cac_configurations
    elsif phishing_resistant_required? && !reauthentication_context?
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
    @options = configurations.group_by(&:class).flat_map do |klass, set|
      klass.selection_presenters(set)
    end
  end

  def account_reset_or_cancel_link
    account_reset_token_valid? ? account_reset_cancel_link : account_reset_link
  end

  def cancel_link
    if @reauthentication_context
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
        t('two_factor_authentication.account_reset.pending'),
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
