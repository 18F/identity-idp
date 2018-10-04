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
    options = mfa.two_factor_configurations
    if TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).enabled?
      options << mfa.personal_key_configuration
    end
    # A user can have multiples of certain types of MFA methods, such as
    # webauthn keys and phones. However, we only want to show one of each option
    # during login, except for phones, where we want to allow the user to choose
    # which MFA-enabled phone they want to use.
    all_sms_and_voice_options_plus_one_of_each_remaining_option(options)
  end

  def should_display_account_reset_or_cancel_link?
    # IAL2 users should not be able to reset account to comply with AAL2 reqs
    !current_user.decorate.identity_verified?
  end

  def account_reset_or_cancel_link
    account_reset_token_valid? ? account_reset_cancel_link : account_reset_link
  end

  private

  def all_sms_and_voice_options_plus_one_of_each_remaining_option(options)
    options_grouped_by_class(options).flat_map do |class_name, instances|
      if not_phone_option_and_more_than_one_instance?(class_name, instances)
        instances.first
      else
        instances
      end
    end
  end

  def options_grouped_by_class(options)
    options.flat_map(&:selection_presenters).group_by { |presenter| presenter.class.to_s }
  end

  def not_phone_option_and_more_than_one_instance?(class_name, instances)
    instances.size > 1 && not_phone_presenter_class?(class_name)
  end

  def not_phone_presenter_class?(class_name)
    phone_classes = [
      'TwoFactorAuthentication::SmsSelectionPresenter',
      'TwoFactorAuthentication::VoiceSelectionPresenter',
    ]
    !phone_classes.include?(class_name)
  end

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
