# frozen_string_literal: true

module Idv
  module Steps
    module ThreatMetrixStepHelper
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

      # @return [Array<String>]
      def threatmetrix_javascript_urls(session_id)
        sources = if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
                    Rails.application.config.asset_sources.get_sources('mock-device-profiling')
                  else
                    ['https://h.online-metrix.net/fp/tags.js']
                  end

        sources.map do |source|
          UriService.add_params(
            source,
            org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
            session_id: session_id,
          )
        end
      end

      def threatmetrix_iframe_url(session_id)
        source = if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
                   Rails.application.routes.url_helpers.test_device_profiling_iframe_url
                 else
                   'https://h.online-metrix.net/fp/tags'
                 end

        UriService.add_params(
          source,
          org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
          session_id: session_id,
        )
      end
    end
  end
end
