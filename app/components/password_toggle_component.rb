class PasswordToggleComponent < BaseComponent
  attr_reader :form, :field_options, :tag_options

  def initialize(
    form:,
    field_options: {},
    **tag_options
  )
    @form = form
    @field_options = field_options
    @tag_options = tag_options
  end

  def label_text
    field_options[:label] || t('components.password_toggle.label')
  end

  def visibility_label_attributes
    {}
  end

  def toggle_id
    "password-toggle-#{unique_id}"
  end

  def input_id
    "password-toggle-input-#{unique_id}"
  end
end
