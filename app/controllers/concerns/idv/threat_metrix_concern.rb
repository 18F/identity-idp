# frozen_string_literal: true

module Idv
  module ThreatMetrixConcern
    THREAT_METRIX_DOMAIN = 'h.online-metrix.net'
    THREAT_METRIX_WILDCARD_DOMAIN = '*.online-metrix.net'

    def override_csp_for_threat_metrix
      return unless Rails.env.production?

      return unless IdentityConfig.store.proofing_device_profiling_collecting_enabled

      return if params[:step] != 'ssn'

      policy = current_content_security_policy

      # ThreatMetrix requires additional Content Security Policy (CSP)
      # directives to be added to the response to enable its JS to run
      # in the browser.

      # `script-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS (so it can be included on the page)
      #   - `unsafe-eval`, since the ThreatMetrix JS uses eval() internally.
      add_to_policy policy, :script_src, THREAT_METRIX_DOMAIN, :unsafe_eval

      # `style-src` must be update to enable:
      #   - `unsafe-inline`, since the ThreatMetrix library applies inline
      #      styles to elements it inserts into the DOM
      add_to_policy policy, :style_src, :unsafe_inline

      # `img-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS, since ThreatMetrix loads
      #     images from this domain as part of its fingerprinting process.
      add_to_policy policy, :img_src, THREAT_METRIX_WILDCARD_DOMAIN

      # `connect-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS, since ThreatMetrix makes XHR
      #     requests to this domain.
      add_to_policy policy, :connect_src, THREAT_METRIX_DOMAIN

      # `child-src` must be updated to enable:
      #   - The domain hosting ThreatMetrix JS, which used to load a fallback
      #     `<iframe>` element when Javascript is disabled.
      add_to_policy policy, :child_src, THREAT_METRIX_DOMAIN

      request.content_security_policy = policy
    end

    private

    def add_to_policy(policy, directive, *values)
      existing_values = policy.directives[directive]

      new_values = [existing_values, values].flatten.uniq.compact

      policy.send(directive, *new_values)
    end
  end
end
