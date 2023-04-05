class PasswordConfirmationComponent < BaseComponent
  attr_reader :form, :label, :toggle_label, :field_options, :tag_options

  def initialize(
    form:,
    toggle_label: t('components.password_toggle.toggle_label'),
    field_options: {},
    **tag_options
  )
    @form = form
    @label = label
    @toggle_label = toggle_label
    @field_options = field_options
    @tag_options = tag_options
  end

  def default_label
    t('components.password_toggle.label')
  end

  # TODO: Add translation
  def confirmation_label
    'todo replace'
  end

  def toggle_id
    "password-toggle-#{unique_id}"
  end

  def input_id
    "password-input-#{unique_id}"
  end

  def input_confirmation_id
    "password-confirmation-input-#{unique_id}"
  end
end
