class WebauthnVisitForm
  include ActiveModel::Model
  include ActionView::Helpers::UrlHelper
  include Rails.application.routes.url_helpers

  attr_reader :url_options, :in_mfa_selection_flow

  INVALID_STATE_ERROR = 'InvalidStateError'
  NOT_SUPPORTED_ERROR = 'NotSupportedError'

  def initialize(user:, url_options:, in_mfa_selection_flow:)
    @user = user
    @url_options = url_options
    @in_mfa_selection_flow = in_mfa_selection_flow
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
      errors.add error, translate_platform_authenticator_error(error),
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
      if in_mfa_selection_flow
        I18n.t(
          'errors.webauthn_platform_setup.account_setup_error',
          link: link_to(
            I18n.t('errors.webauthn_platform_setup.choose_another_method'),
            authentication_methods_setup_path,
          ),
        )
      else
        I18n.t('errors.webauthn_platform_setup.general_error')
      end
    end
  end

  def translate_error(error)
    case error
    when INVALID_STATE_ERROR
      I18n.t('errors.webauthn_setup.already_registered')
    when NOT_SUPPORTED_ERROR
      I18n.t('errors.webauthn_setup.not_supported')
    else
      I18n.t(
        'errors.webauthn_setup.general_error',
        link: link_to(
          I18n.t('errors.webauthn_setup.additional_methods_link'),
          authentication_methods_setup_path,
        ),
      )
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
