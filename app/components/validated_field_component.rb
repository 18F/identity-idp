class ValidatedFieldComponent < BaseComponent
  attr_reader :form, :name, :label, :hint, :type, :tag_options, :input_type

  alias_method :f, :form

  def initialize(form:, name:, label:, hint: nil, type: nil, error_messages: {}, **tag_options)
    @form = form
    @name = name
    @label = label
    @hint = hint
    @type = type
    @error_messages = error_messages
    @tag_options = tag_options
    @input_type = inferred_input_type
  end

  def error_messages
    {
      valueMissing: value_missing_error_message,
      typeMismatch: type_mismatch_error_message,
      **@error_messages,
    }.compact
  end

  def aria_describedby_idrefs
    idrefs = [*tag_options.dig(:input_html, :aria, :describedby)]
    idrefs << error_id if has_errors?
    idrefs << hint_id if has_hint?
    idrefs
  end

  def error_message
    form.object.errors[name].full_messages.first if has_errors?
  end

  def has_errors?
    form.object.respond_to?(:errors) && form.object.errors.key?(name)
  end

  def has_hint?
    tag_options.key?(:hint)
  end

  def input_id
    "validated-field-input-#{unique_id}"
  end

  def error_id
    "validated-field-error-#{unique_id}"
  end

  def hint_id
    "validated-field-hint-#{unique_id}"
  end

  private

  def value_missing_error_message
    case input_type
    when :boolean
      t('forms.validation.required_checkbox')
    else
      t('simple_form.required.text')
    end
  end

  def type_mismatch_error_message
    case input_type
    when :email
      t('valid_email.validations.email.invalid')
    end
  end

  def inferred_input_type
    if type.present?
      type
    elsif tag_options.key?(:as)
      tag_options[:as]
    elsif form.respond_to?(:default_input_type)
      form.send(:default_input_type, name, form.send(:find_attribute_column, name), tag_options)
    else
      :text
    end
  end
end
