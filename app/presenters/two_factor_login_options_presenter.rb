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

  # :reek:FeatureEnvy
  def options
    mfa = current_user.mfa
    # for now, we include the personal key since that's our current behavior,
    # but there are designs to remove personal key from the option list and
    # make it a link with some additional text to call it out as a special
    # case.
    (
      mfa.two_factor_configurations + [mfa.personal_key_configuration]
    ).flat_map(&:selection_presenters)
  end

  def should_display_account_reset_or_cancel_link?
    # IAL2 users should not be able to reset account to comply with AAL2 reqs
    !current_user.decorate.identity_verified?
  end

  def account_reset_or_cancel_link
    account_reset_token_valid? ? account_reset_cancel_link : account_reset_link
  end

  private

  def account_reset_link
    t('two_factor_authentication.account_reset.text_html',
      link: @view.link_to(
        t('two_factor_authentication.account_reset.link'),
        account_reset_request_path(locale: LinkLocaleResolver.locale)
      ))
  end

  def account_reset_cancel_link
    t('two_factor_authentication.account_reset.pending_html',
      cancel_link: @view.link_to(
        t('two_factor_authentication.account_reset.cancel_link'),
        account_reset_cancel_url(token: account_reset_token)
      ))
  end

  def account_reset_token
    current_user&.account_reset_request&.request_token
  end

  def account_reset_token_valid?
    current_user&.account_reset_request&.granted_token_valid?
  end
end
