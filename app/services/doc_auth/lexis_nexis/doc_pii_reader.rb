# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module DocPiiReader
      include DocAuth::LexisNexis::DocPiiConcern

      def first_name
        id_auth_field_data&.dig('Fields_FirstName')
      end
    end
  end
end
