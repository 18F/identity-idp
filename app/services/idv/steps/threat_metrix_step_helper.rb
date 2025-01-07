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
        if should_generate_new_threatmetrix_session_id?(updating_ssn)
          idv_session.threatmetrix_session_id = SecureRandom.uuid
        end

        idv_session.threatmetrix_session_id
      end

      def should_generate_new_threatmetrix_session_id?(updating_ssn)
        if updating_ssn
          idv_session.threatmetrix_session_id.blank?
        else
          true
        end
      end
    end
  end
end
