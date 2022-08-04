class MemorableDateComponent < BaseComponent
    # include ActiveModel::Validations
    attr_reader :month, :day, :year, :hint, :label, :form
    #, :input_type, :tag_options

    alias_method :f, :form
    # validates :month, numericality: true .... validates checks value b4 you write to the db 

    def initialize(month:, day:, year:, hint:, label:, form:, error_messages: {}, **tag_options)
        @month = month
        @day = day
        @year = year
        @hint = hint
        @label = label
        @form = form
         @error_messages = error_messages
        # @input_type = inferred_input_type
         @tag_options = []
    end

    # if error then we need to add this css class: usa-input--error
    def error_messages
        # { valueMissing: value_missing_error_message }.compact
    end

#     private

#     # pattern is what is showing the current error now 
#     # when input type is false, ie missing, then add the error text "required"
#     def value_missing_error_message
#         case input_type
#         when :boolean
#         t('forms.validation.required_checkbox')
#         else
#         t('simple_form.required.text')
#         end
#   end

#   def inferred_input_type
#     # change this so instead it validates field is number
#     form.send(:default_input_type, month, form.send(:find_attribute_column, month ), tag_options)
#   end
end