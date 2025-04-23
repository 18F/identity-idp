# frozen_string_literal: true

module DocAuth
  module Mock
    class DosPassportApiClient
      def initialize(lexis_nexis_response)
        @lexis_nexis_response = lexis_nexis_response
      end

      def fetch
        DocAuth::Response.new(success: true)
      end

      private

      attr_accessor :lexis_nexis_response
    end
  end
end
