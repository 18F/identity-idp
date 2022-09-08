module Scripts
  module InheritedProofing
    module Errorable
      module_function

      def puts_message(message)
        puts message
      end

      def puts_success(message)
        puts_message "Success: #{message}"
      end

      def puts_warning(message)
        puts_message "Warning: #{message}"
      end

      def puts_error(message)
        puts_message "Oops! An error occurred: #{message}"
      end
    end
  end
end
