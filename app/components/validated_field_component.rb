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
      valueMissing: t('simple_form.required.text'),
      **@error_messages,
    }
  end
end
