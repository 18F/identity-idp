# frozen_string_literal: true

module UspsInPersonProofing
  class EippHelper
    class << self
      def extract_vector_of_trust(sp_session)
        sp_session['vtr']
      end

      def is_eipp?(vector_of_trust)
        !!vector_of_trust&.first&.include?('Pe')
      end
    end
  end
end
