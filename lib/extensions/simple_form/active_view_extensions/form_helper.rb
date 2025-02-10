# frozen_string_literal: true

# Monkey-patch SimpleForm::ActionViewExtensions::FormHelper apply default `autocomplete` attribute.
#
# See: https://github.com/heartcombo/simple_form/blob/main/lib/simple_form/action_view_extensions/form_helper.rb

module Extensions
  SimpleForm::ActionViewExtensions::FormHelper.class_eval do
    prepend(
      Module.new do
        def simple_form_for(record, options = {}, &block)
          options[:html] ||= {}
          options[:html][:autocomplete] ||= 'off'
          super(record, options, &block)
        end
      end,
    )
  end
end
