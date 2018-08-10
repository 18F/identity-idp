class TwoFactorLoginOptionsPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
  include ActionView::Helpers::TranslationHelper

  POSSIBLE_OPTIONS = %i[sms voice auth_app piv_cac personal_key].freeze
  POLICIES = {
    sms: SmsLoginOptionPolicy,
    voice: VoiceLoginOptionPolicy,
    auth_app: AuthAppLoginOptionPolicy,
    piv_cac: PivCacLoginOptionPolicy,
    personal_key: PersonalKeyLoginOptionPolicy,
  }.freeze

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
    configured_2fa_types.map do |type|
      OpenStruct.new(
        type: type,
        label: t("two_factor_authentication.login_options.#{type}"),
        info: t("two_factor_authentication.login_options.#{type}_info"),
        selected: type == configured_2fa_types[0]
      )
    end
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
    t('devise.two_factor_authentication.account_reset.text_html',
      link: @view.link_to(
        t('devise.two_factor_authentication.account_reset.link'),
        account_reset_request_path(locale: LinkLocaleResolver.locale)
      ))
  end

  def account_reset_cancel_link
    t('devise.two_factor_authentication.account_reset.pending_html',
      cancel_link: @view.link_to(
        t('devise.two_factor_authentication.account_reset.cancel_link'),
        account_reset_cancel_url(token: account_reset_token)
      ))
  end

  def account_reset_token
    current_user&.account_reset_request&.request_token
  end

  def account_reset_token_valid?
    current_user&.account_reset_request&.granted_token_valid?
  end

  def configured_2fa_types
    POSSIBLE_OPTIONS.each_with_object([]) do |option, result|
      result << option if POLICIES[option].new(@current_user).configured?
    end
  end
end
