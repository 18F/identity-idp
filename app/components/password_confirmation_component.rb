class PasswordConfirmationComponent < BaseComponent
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
