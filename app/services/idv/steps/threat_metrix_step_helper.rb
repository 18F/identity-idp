# frozen_string_literal: true

module Idv
  module Steps
    module ThreatMetrixStepHelper 
      include ThreatMetrixHelper
      def threatmetrix_view_variables(updating_ssn)
        session_id = generate_threatmetrix_session_id(updating_ssn)

        {
          threatmetrix_session_id: session_id,
          threatmetrix_javascript_urls: session_id && threatmetrix_javascript_urls(session_id),
          threatmetrix_iframe_url: session_id && threatmetrix_iframe_url(session_id),
        }
      end

      def generate_threatmetrix_session_id(updating_ssn)
        idv_session.threatmetrix_session_id = SecureRandom.uuid if !updating_ssn
        idv_session.threatmetrix_session_id
      end
    end
  end
end
