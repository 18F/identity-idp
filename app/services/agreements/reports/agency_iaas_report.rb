module Agreements
  module Reports
    class AgencyIaasReport < BaseReport
      def initialize(agency:, iaas:)
        @agency = agency
        @iaas = iaas.sort_by do |iaa|
          [iaa.partner_account, iaa.iaa_number]
        end
      end

      def run
        save_report(
          'agreements',
          IaaBlueprint.render(iaas, root: :agreements),
          extension: 'json',
        )
      end

      def report_path
        "agencies/#{agency.downcase}/"
      end

      private

      attr_reader :agency, :iaas
    end
  end
end
