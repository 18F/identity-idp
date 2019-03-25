class TwoFactorLoginOptionsPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user

  def initialize(current_user, view, service_provider)
    @current_user = current_user
    @view = view
    @service_provider = service_provider
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

  def label
    ''
  end

  def options
    mfa = MfaContext.new(current_user)
    # for now, we include the personal key since that's our current behavior,
    # but there are designs to remove personal key from the option list and
    # make it a link with some additional text to call it out as a special
    # case.
    configurations = mfa.two_factor_configurations
    if TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?
      configurations << mfa.personal_key_configuration
    end
    # A user can have multiples of certain types of MFA methods, such as
    # webauthn keys and phones. However, we only want to show one of each option
    # during login, except for phones, where we want to allow the user to choose
    # which MFA-enabled phone they want to use.
    configurations.group_by(&:class).flat_map { |klass, set| klass.selection_presenters(set) }
  end

  def should_display_account_reset_or_cancel_link?
    # IAL2 non-docauth users should not be able to reset account to comply with AAL2 reqs
    !current_user.decorate.identity_verified? || FeatureManagement.doc_auth_enabled?
  end

  def account_reset_or_cancel_link
    account_reset_token_valid? ? account_reset_cancel_link : account_reset_link
  end

  def reverify_link
    t('two_factor_authentication.account_reset.recover_html',
      link: @view.link_to(
        t('two_factor_authentication.account_reset.recover_link'),
        account_reset_recover_path,
      ))
  end

  private

  def account_reset_link
    t('two_factor_authentication.account_reset.text_html',
      link: @view.link_to(
        t('two_factor_authentication.account_reset.link'),
        account_reset_request_path(locale: LinkLocaleResolver.locale),
      ))
  end

  def account_reset_cancel_link
    t('two_factor_authentication.account_reset.pending_html',
      cancel_link: @view.link_to(
        t('two_factor_authentication.account_reset.cancel_link'),
        account_reset_cancel_url(token: account_reset_token),
      ))
  end

  def account_reset_token
    current_user&.account_reset_request&.request_token
  end

  def account_reset_token_valid?
    current_user&.account_reset_request&.granted_token_valid?
  end
end
