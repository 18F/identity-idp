# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Ddp
      module DocPiiReader
        include DocAuth::LexisNexis::DocPiiConcern

        def first_name
          id_auth_field_data&.dig('Fields_FirstName') || id_auth_field_data&.dig('Fields_GivenName')
        end
      end
    end
  end
end
