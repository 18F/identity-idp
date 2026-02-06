# frozen_string_literal: true

module Idv
  module InPerson
    class PostOfficePresenter
      include FormHelper

      def states
        us_states_territories.reject { |_name, abbrev| %w[AA AE AP UM].include?(abbrev) }
      end
    end
  end
end
