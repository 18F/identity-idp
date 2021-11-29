class WebauthnVisitForm
  include ActiveModel::Model

  def submit(params)
    check_params(params)
    @platform_authenticator = params[:platform].to_s == 'true'
    FormResponse.new(success: errors.empty?, errors: errors, extra: extra_analytics_attributes)
  end

  def check_params(params)
    error = params[:error]
    return unless error

    error_h = {
      'InvalidStateError' => I18n.t('errors.webauthn_setup.already_registered'),
      'NotSupportedError' => I18n.t('errors.webauthn_setup.not_supported'),
    }
    errors.add error, error_h[error] || I18n.t('errors.webauthn_setup.general_error')
  end

  def platform_authenticator?
    @platform_authenticator
  end

  private

  def extra_analytics_attributes
    {
      platform_authenticator: platform_authenticator?,
    }
  end
end
