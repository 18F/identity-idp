# @label WebAuthn Input
class WebauthnInputComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(WebauthnInputComponent.new) { |c| c.render(checkbox(c)) }
  end

  def with_platform_option
    render(WebauthnInputComponent.new(platform: true)) { |c| c.render(checkbox(c)) }
  end
  # @!endgroup

  # @param platform toggle
  def workbench(platform: false)
    render(WebauthnInputComponent.new(platform:)) { |c| c.render(checkbox(c)) }
  end

  private

  def checkbox(component)
    ValidatedFieldComponent.new(
      form: form_builder,
      name: checkbox_name(component),
      label: checkbox_label(component),
      as: :boolean,
    )
  end

  def checkbox_name(component)
    if component.platform?
      'webauthn_platform'
    else
      'webauthn'
    end
  end

  def checkbox_label(component)
    if component.platform?
      I18n.t('two_factor_authentication.login_options.webauthn_platform')
    else
      I18n.t('two_factor_authentication.login_options.webauthn')
    end
  end
end
