module InPerson
  module EnrollmentsReadyForStatusCheck
    module UsesReportError
      def report_error(err, **_message_ids)
        err = StandardError.new("#{self.class.name}: #{err}") if error.is_a?(String)
        NewRelic::Agent.notice_error(err)
      end
    end
  end
end
