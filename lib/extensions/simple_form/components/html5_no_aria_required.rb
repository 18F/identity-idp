module SimpleForm
  module Components
    module HTML5NoAriaRequired
      include HTML5

      def html5_no_aria_required(_wrapper_options)
        input_html_options[:required] = input_html_required_option
        input_html_options[:'aria-invalid'] = has_errors? || nil
        nil
      end
    end
  end
end

SimpleForm.include_component(SimpleForm::Components::HTML5NoAriaRequired)
