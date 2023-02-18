class TransliterableFieldGroupComponent < BaseComponent
    attr_reader :form, :fields, :validation_url, :form_error_message, :block

    def initialize(form:, fields:, validation_url:, form_error_selector: nil, form_error_message: nil, &block)
        @form = form
        @fields = fields
        @validation_url = validation_url
        @form_error_selector = form_error_selector
        @fallback_error_class = 'transliterable-form__error-display'
        @form_error_message = form_error_message
        @block = block
    end

    def form_error_class
        @fallback_error_class unless @form_error_selector
    end

    def form_error_selector
        @form_error_selector || ".#{@fallback_error_class}"
    end

    def field_mapping
        mapping = Hash.new
        @fields.each do |field_name|
            mapping["#{form.object_name}[#{field_name.to_s}]"] = field_name.to_s
        end
        mapping
    end
end