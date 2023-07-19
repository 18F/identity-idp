# frozen_string_literal: true

module Idv
  module ThreatMetrixConcern
    THREAT_METRIX_DOMAIN = 'h.online-metrix.net'
    THREAT_METRIX_WILDCARD_DOMAIN = '*.online-metrix.net'

    def override_csp_for_threat_metrix
      return unless FeatureManagement.proofing_device_profiling_collecting_enabled?

      return if params[:step] != 'ssn'

      threat_metrix_csp_overrides
    end

    # Remove this duplication once in_person_controller is no longer in use
    # for their SSN step
    def override_csp_for_threat_metrix_no_fsm
      return unless FeatureManagement.proofing_device_profiling_collecting_enabled?

      ##
      # In order to test the behavior without the CSP changes, we do not perform the CSP override
      # if the user's email is on a list of CSP disabled emails.
      #
      current_user.email_addresses.each do |email_address|
        no_csp_email = IdentityConfig.store.idv_tmx_test_csp_disabled_emails.include?(
          email_address.email,
        )
        return nil if no_csp_email
      end

      threat_metrix_csp_overrides
    end

    def threat_metrix_csp_overrides
      policy = current_content_security_policy

      # ThreatMetrix requires additional Content Security Policy (CSP)
      # directives to be added to the response to enable its JS to run
      # in the browser.

      # `script-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS (so it can be included on the page)
      #   - `unsafe-eval`, since the ThreatMetrix JS uses eval() internally.
      policy.script_src(*policy.script_src.to_set.merge([THREAT_METRIX_DOMAIN, :unsafe_eval]))

      # `style-src` must be updated to enable:
      #   - `unsafe-inline`, since the ThreatMetrix library applies inline
      #      styles to elements it inserts into the DOM
      policy.style_src(*(policy.style_src.to_set << :unsafe_inline))

      # `img-src` must be updated to enable:
      #   - A wildcard domain, since the JS loads images from different
      #     subdomains of the main ThreatMetrix domain.
      policy.img_src(*(policy.img_src.to_set << THREAT_METRIX_WILDCARD_DOMAIN))

      # `connect-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS, since ThreatMetrix makes XHR
      #     requests to this domain.
      policy.connect_src(*(policy.connect_src.to_set << THREAT_METRIX_DOMAIN))

      # `child-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS, which used to load a fallback
      #     `<iframe>` element when Javascript is disabled.
      policy.child_src(*(policy.child_src.to_set << THREAT_METRIX_DOMAIN))

      request.content_security_policy = policy
    end
  end
end
