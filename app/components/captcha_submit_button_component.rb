# frozen_string_literal: true

class CaptchaSubmitButtonComponent < BaseComponent
  attr_reader :form, :action, :button_options, :tag_options

  alias_method :f, :form

  # @param [String] action https://developers.google.com/recaptcha/docs/v3#actions
  def initialize(form:, action:, button_options: {}, **tag_options)
    @form = form
    @action = action
    @button_options = button_options
    @tag_options = tag_options
  end

  def show_mock_score_field?
    IdentityConfig.store.recaptcha_mock_validator
  end

  def recaptcha_enterprise?
    FeatureManagement.recaptcha_enterprise?
  end
end
