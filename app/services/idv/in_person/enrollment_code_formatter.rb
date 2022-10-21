module Idv
  module InPerson
    class EnrollmentCodeFormatter
      def self.format(code)
        code.gsub(/(\d{4})/, '\1-').chomp('-')
      end
    end
  end
end
