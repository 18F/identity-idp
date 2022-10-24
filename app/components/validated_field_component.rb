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
    if form.respond_to?(:default_input_type)
      form.send(:default_input_type, name, form.send(:find_attribute_column, name), tag_options)
    elsif tag_options.key?(:as)
      tag_options[:as]
    else
      :text
    end
  end
end
