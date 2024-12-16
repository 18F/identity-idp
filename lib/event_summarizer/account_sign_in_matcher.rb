# frozen_string_literal: true

require 'active_support'
require 'active_support/time'

module EventSummarizer
  class AccountSignInMatcher
    STARTED_EVENT = 'Email and Password Authentication'
    MFA_AUTHENTICATION_LANDING_EVENTS = [
      'Multi-Factor Authentication: enter OTP visited',
      'Multi-Factor Authentication: enter backup code visited',
      'Multi-Factor Authentication: enter webAuthn authentication visited',
      'Multi-Factor Authentication: enter TOTP visited',
      'multi_factor_auth_enter_piv_cac',
      'Multi-Factor Authentication: enter personal key visited',
    ]
    MFA_SUBMITTED_EVENT = 'Multi-Factor Authentication'
    MFA_OPTIONS_LIST_EVENT = 'Multi-Factor Authentication: option list visited'
    MFA_SELECTED_EVENT = 'Multi-Factor Authentication: option list'
    USER_AUTHENTICATED_EVENT = 'User marked authenticated'
    SP_REDIRECTED_EVENT = 'SP redirect initiated'
    ACCOUNT_PAGE_VISITED_EVENT = 'Account Page Visited'



    

    EVENT_PROPERTIES = ['@message', 'properties', 'event_properties'].freeze

    
    class AuthenticationAttempt

      attr_accessor :started_at, :event_summaries
      def initialize(started_at: )
        @started_at = started_at
        event_summaries = Array.new
      end

      def add_summary(summary)
        event_summaries << summary
      end
    end

    class EventSummary
      attr_accessor :event_type, :start_time, :end_time, :success
      def initialize(start_time:, event_type:, success:, message: )
        @event_type = event_type 
        @start_time = start_time
      end
    end

    attr_accessor :current_attempt, :attempts

    # @return {Hash,nil}
    def handle_cloudwatch_event(event)
      @attempts ||= Array.new

      case event['name']
      when STARTED_EVENT
        start_authentication_attempt(event)
      when *MFA_AUTHENTICATION_LANDING_EVENTS

      end
    end

    def finish
      finish_all_attempts

      attempts.map { |attempt| summarize_attempt(attempt) }
    end

    private

    def start_authentication_attempt(event:)
      finish_current_attempt if current_attempt
      start_time = Time.zone.parse(event['@timestamp'])
      success = event.dig(*EVENT_PROPERTIES, 'success') == '1'
      @current_attempt = AuthenticationAttempt.new(
        started_at: start_time,
      )
      start_summary = EventSummary.new(
        start_time: start_time, 
        event_type: 'sign_in_attempt', 
        success: success,
        message: event['@message'],
      )
      current_attempt.add_summary(start_summary)
    end
    
    def finish_current_attempt
      attempts << current_attempt if current_attempt

      current_attempt = nil
    end

    def finish_all_attempts

    end

    def summarize_attempt(attempt)
      
    end
  end
end
