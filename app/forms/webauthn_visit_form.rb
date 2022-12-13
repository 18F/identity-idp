class WebauthnVisitForm
  include ActiveModel::Model

  INVALID_STATE_ERROR = 'InvalidStateError'
  NOT_SUPPORTED_ERROR = 'NotSupportedError'

  def initialize(user)
    @user = user
  end

  def submit(params)
    @platform_authenticator = params[:platform].to_s == 'true'
    check_params(params)
    FormResponse.new(success: errors.empty?, errors: errors, extra: extra_analytics_attributes)
  end

  def platform_authenticator?
    @platform_authenticator
  end

  private

  def check_params(params)
    error = params[:error]
    return unless error

    if @platform_authenticator
      errors.add error,
                 translate_platform_authenticator_error(error),
                 type: :"#{translate_platform_authenticator_error(error).split('.').last}"
    else
      errors.add error, translate_error(error), type: :"#{translate_error(error).split('.').last}"
    end
  end

  def translate_platform_authenticator_error(error)
    case error
    when INVALID_STATE_ERROR
      I18n.t('errors.webauthn_platform_setup.already_registered')
    when NOT_SUPPORTED_ERROR
      I18n.t('errors.webauthn_platform_setup.not_supported')
    else
      I18n.t('errors.webauthn_platform_setup.general_error')
    end
  end

  def translate_error(error)
    case error
    when INVALID_STATE_ERROR
      I18n.t('errors.webauthn_setup.already_registered')
    when NOT_SUPPORTED_ERROR
      I18n.t('errors.webauthn_setup.not_supported')
    else
      I18n.t('errors.webauthn_setup.general_error')
    end
  end

  def mfa_user
    @mfa_user ||= MfaContext.new(@user)
  end

  def extra_analytics_attributes
    {
      platform_authenticator: platform_authenticator?,
      enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
    }
  end
end
