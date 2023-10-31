# Monkey-patch SimpleForm HTML5 module to remove redundant aria-required attribute
# from required fields. Adding aria-required could create a bad user experience.
# Source: https://w3c.github.io/html-aria/#rules-wd
#
# frozen_string_literal: true

module SimpleForm
  module Components
    module HTML5
      def html5
        @html5 = true

        input_html_options[:required] = input_html_required_option

        nil
      end
      end
  end
end
