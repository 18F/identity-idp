class PasswordToggleComponent < BaseComponent
  attr_reader :form, :label, :toggle_label, :toggle_position, :field_options

  def initialize(
    form:,
    label: t('components.password_toggle.label'),
    toggle_label: t('components.password_toggle.toggle_label'),
    toggle_position: :top,
    **field_options
  )
    @form = form
    @label = label
    @toggle_label = toggle_label
    @toggle_position = toggle_position
    @field_options = field_options
  end

  def css_class
    classes = []
    classes << 'password-toggle--toggle-top' if toggle_position == :top
    classes << 'password-toggle--toggle-bottom' if toggle_position == :bottom
    classes
  end

  def toggle_id
    "password-toggle-#{unique_id}"
  end

  def input_id
    "password-toggle-input-#{unique_id}"
  end

  def field
    ValidatedFieldComponent.new(
      form: form,
      name: :password,
      type: :password,
      label: label,
      **field_options,
      input_html: field_options[:input_html].to_h.merge(
        id: input_id,
        class: ['password-toggle__input', *field_options.dig(:input_html, :class)],
      ),
    )
  end
end
