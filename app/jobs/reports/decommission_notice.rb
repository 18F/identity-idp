# frozen_string_literal: true

module Reports
  # Shared blurb warning partners that a report is being decommissioned in favor of
  # the partner portal's reporting feature.
  module DecommissionNotice
    DECOMMISSION_DATE = 'November 1, 2026'

    # @return [String] HTML, marked html_safe, meant to be appended to a
    #   report email's message/preamble.
    def decommission_notice
      <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        <div class="usa-alert usa-alert--warning usa-alert--email">
          <div class="usa-alert__body">
            <p class="usa-alert__text">
              This automated report will be decommissioned beginning #{DECOMMISSION_DATE}.
              We have recently launched a new reporting feature in our production partner
              portal and will therefore be decommissioning subsequent emailed reports. The
              reporting in the partner portal includes our most up-to-date statistics,
              models, and functionality being added frequently. To view reports in the
              portal, you must be an Admin or a Reports-only user. Admins can create
              Reports-only users or you can reach out to us at
              <a href="mailto:partners@login.gov">partners@login.gov</a> for assistance.
            </p>
          </div>
        </div>
      HTML
    end
  end
end
