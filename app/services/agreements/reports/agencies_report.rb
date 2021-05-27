module Agreements
  module Reports
    class AgenciesReport < BaseReport
      def initialize(agencies:)
        @agencies = agencies
      end

      def run
        save_report(
          'agencies',
          AgencyBlueprint.render(agencies, root: :agencies),
        )
      end

      # Save in the root directory
      def report_path
        ''
      end

      private

      attr_reader :agencies
    end
  end
end
