require 'reporting/cloudwatch_query'
require 'reporting/cloudwatch_client'

module Reporting
  class IdentityVerificationReport
    include CloudwatchQuery::Quoting

    attr_reader :issuer

    def initialize(issuer:)
      @issuer = issuer
    end


    def fetch_results

    end

    def query
      params = {
        issuer: quote(issuer),
        event_names: quote(
          [
            'IdV: doc auth image upload vendor submitted',
            'IdV: USPS address letter requested',
            'USPS IPPaaS enrollment created',
            'IdV: final resolution',
            'GPO verification submitted',
            'GetUspsProofingResultsJob: Enrollment status updated',
          ],
        )
      }

      format(<<-QUERY, params)
        fields @message, @timestamp
        | filter properties.service_provider = %{issuer}
        | filter name in %{event_names}
        | stats count(*) by name
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_template ||= 
    end
  end
end