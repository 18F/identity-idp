class PasswordConfirmationComponent < BaseComponent
  attr_reader :form, :toggle_label, :field_options, :tag_options

  def initialize(
    form:,
    toggle_label: t('components.password_confirmation.toggle_label'),
    field_options: {},
    **tag_options
  )
    @form = form
    @toggle_label = toggle_label
    @field_options = field_options
    @tag_options = tag_options
  end

  def default_label
    t('forms.password')
  end

  def confirmation_label
    t('components.password_confirmation.confirm_label')
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
