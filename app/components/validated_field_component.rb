class ValidatedFieldComponent < BaseComponent
  attr_reader :form, :name, :tag_options, :input_type

  alias_method :f, :form

  def initialize(form:, name:, error_messages: {}, **tag_options)
    @form = form
    @name = name
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
    idrefs << "validated-field-error-#{unique_id}" if has_errors?
    idrefs << "validated-field-hint-#{unique_id}" if has_hint?
    idrefs
  end

  private

  def has_errors?
    form.object.respond_to?(:errors) && form.object.errors.key?(name)
  end

  def has_hint?
    tag_options.key?(:hint)
  end

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
    if form.respond_to?(:default_input_type)
      form.send(:default_input_type, name, form.send(:find_attribute_column, name), tag_options)
    elsif tag_options.key?(:as)
      tag_options[:as]
    else
      :text
    end
  end
end
