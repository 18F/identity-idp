class ValidatedFieldComponent < BaseComponent
  attr_reader :form, :name, :tag_options

  alias_method :f, :form

  def initialize(form:, name:, error_messages: {}, **tag_options)
    @form = form
    @name = name
    @error_messages = error_messages
    @tag_options = tag_options
  end

  def error_messages
    {
      valueMissing: value_missing_error_message,
      **@error_messages,
    }
  end

  private

  def value_missing_error_message
    case form.send(:default_input_type, name, form.send(:find_attribute_column, name), tag_options)
    when :boolean
      t('forms.validation.required_checkbox')
    else
      t('simple_form.required.text')
    end
  end
end
