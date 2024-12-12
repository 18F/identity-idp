# frozen_string_literal: true

require 'active_support'
require 'active_support/time'

# module EventSummarizer
#   class AuthenticationMatcher
#     STARTED_EVENT = 'Email and Password Authentication'
#     MFA_AUTHENTICATION_LANDING_EVENTS = [
#       'Multi-Factor Authentication: enter OTP visited',
#       'Multi-Factor Authentication: enter backup code visited',
#       'Multi-Factor Authentication: enter webAuthn authentication visited',
#       'Multi-Factor Authentication: enter TOTP visited',
#       'multi_factor_auth_enter_piv_cac',
#       'Multi-Factor Authentication: enter personal key visited',
#     ]

#     MFA_SUBMITTED_EVENT = 'Multi-Factor Authentication'

    

#     EVENT_PROPERTIES = ['@message', 'properties', 'event_properties'].freeze

    
#     class AuthenticationAttempt

#       attr_accessor :started_at, :events

#       def initialize

#       end
#     end

#     attr_reader :current_attempt
#     attr_reader :attempts

#     # @return {Hash,nil}
#     def handle_cloudwatch_event(event)
#       @attempts ||= Array.new

#       case event['name']
#       end
#     end

#     def finish
#       finish_all_attempts

#       attempts.map { |attempt| summarize_attempt(attempt) }
#     end

#     private

#     def start_new_attempt(event:)
#       finish_current_attempt if current_attempt

#       @current_idv_attempt = IdvAttempt.new(
#         started_at: Time.zone.parse(event['@timestamp']),
#       )
#     end

#     def summarize_attempt(attempt)
      
#     end
#   end
# end
