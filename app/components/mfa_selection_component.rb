class MfaSelectionComponent < BaseComponent
    attr_reader :form, :name, :option, :tag_options

    alias_method :f, :form

    def initialize(form:, name:, option:, error_messages: {}, **tag_options)
    @form = form
    @name = name
    @option = option
    @error_messages = error_messages
    @tag_options = tag_options
    end

    def error_messages
    {
      valueMissing: t('forms.validation.required_checkbox'),
      **@error_messages,
    }.compact
    end
end
