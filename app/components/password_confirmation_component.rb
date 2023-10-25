# frozen_string_literal: true

class PasswordConfirmationComponent < BaseComponent
  attr_reader :form, :field_options, :tag_options

  def initialize(
    form:,
    password_label: nil,
    confirmation_label: nil,
    field_options: {},
    **tag_options
  )
    @form = form
    @password_label = password_label
    @confirmation_label = confirmation_label
    @field_options = field_options
    @tag_options = tag_options
  end

  def password_label
    @password_label || t('forms.password')
  end

  def confirmation_label
    @confirmation_label || t('components.password_confirmation.confirm_label')
  end

  def toggle_id
    "password-confirmation-toggle-#{unique_id}"
  end

  def input_id
    "password-confirmation-input-#{unique_id}"
  end

  def input_confirmation_id
    "password-confirmation-input-confirmation-#{unique_id}"
  end
end
