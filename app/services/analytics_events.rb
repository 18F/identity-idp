# frozen_string_literal: true

#  ______________________________________
# / Adding something new in here? Please \
# \ keep methods sorted alphabetically.  /
#  --------------------------------------
#         \   ^__^
#          \  (oo)\_______
#             (__)\       )\/\
#                 ||----w |
#                 ||     ||
#
# Methods are organized into domain-specific sub-modules.
# See app/services/analytics_events/ for each domain module.

require_relative 'analytics_events/account_events'
require_relative 'analytics_events/account_reset_events'
require_relative 'analytics_events/authentication_events'
require_relative 'analytics_events/email_events'
require_relative 'analytics_events/fraud_events'
require_relative 'analytics_events/gpo_events'
require_relative 'analytics_events/idv_document_capture_events'
require_relative 'analytics_events/idv_events'
require_relative 'analytics_events/idv_in_person_events'
require_relative 'analytics_events/navigation_events'
require_relative 'analytics_events/profile_events'
require_relative 'analytics_events/sp_events'

module AnalyticsEvents
  def self.included(base)
    base.include AccountEvents
    base.include AccountResetEvents
    base.include AuthenticationEvents
    base.include EmailEvents
    base.include FraudEvents
    base.include GpoEvents
    base.include IdvDocumentCaptureEvents
    base.include IdvEvents
    base.include IdvInPersonEvents
    base.include NavigationEvents
    base.include ProfileEvents
    base.include SpEvents
  end
end
