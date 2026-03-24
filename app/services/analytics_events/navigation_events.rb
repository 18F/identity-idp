# frozen_string_literal: true

module AnalyticsEvents
  module NavigationEvents

    # @param [String] redirect_url URL user was directed to
    # @param [String, nil] step which step
    # @param [String, nil] location which part of a step, if applicable
    # @param ["idv", String, nil] flow which flow
    # User was redirected to the login.gov contact page
    def contact_redirect(redirect_url:, step: nil, location: nil, flow: nil, **extra)
      track_event(
        'Contact Page Redirect',
        redirect_url: redirect_url,
        step: step,
        location: location,
        flow: flow,
        **extra,
      )
    end

    # New device sign-in alerts sent after expired notification timeframe
    # @param [Integer] count Number of emails sent
    def create_new_device_alert_job_emails_sent(count:, **extra)
      track_event(:create_new_device_alert_job_emails_sent, count:, **extra)
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Time, nil] event_created_at timestamp for the event
    # @param [Time, nil] disavowed_device_last_used_at
    # @param [String, nil] disavowed_device_user_agent
    # @param [String, nil] disavowed_device_last_ip
    # @param [Integer, nil] event_id events table id
    # @param [String, nil] event_type (see Event#event_type)
    # @param [String, nil] event_ip ip address for the event
    # @param [String, nil] user_id UUID of the user
    # Tracks disavowed event
    def event_disavowal(
      success:,
      user_id:,
      error_details: nil,
      event_created_at: nil,
      disavowed_device_last_used_at: nil,
      disavowed_device_user_agent: nil,
      disavowed_device_last_ip: nil,
      event_id: nil,
      event_type: nil,
      event_ip: nil,
      **extra
    )
      track_event(
        'Event disavowal visited',
        success:,
        error_details:,
        event_created_at:,
        disavowed_device_last_used_at:,
        disavowed_device_user_agent:,
        disavowed_device_last_ip:,
        event_id:,
        event_type:,
        event_ip:,
        user_id:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Time, nil] event_created_at timestamp for the event
    # @param [Time, nil] disavowed_device_last_used_at
    # @param [String, nil] disavowed_device_user_agent
    # @param [String, nil] disavowed_device_last_ip
    # @param [Integer, nil] event_id events table id
    # @param [String, nil] event_type (see Event#event_type)
    # @param [String, nil] event_ip ip address for the event
    # @param [String, nil] user_id UUID of the user
    # Event disavowal password reset was performed
    def event_disavowal_password_reset(
      success:,
      user_id:,
      error_details: nil,
      event_created_at: nil,
      disavowed_device_last_used_at: nil,
      disavowed_device_user_agent: nil,
      disavowed_device_last_ip: nil,
      event_id: nil,
      event_type: nil,
      event_ip: nil,
      **extra
    )
      track_event(
        'Event disavowal password reset',
        success:,
        error_details:,
        event_created_at:,
        disavowed_device_last_used_at:,
        disavowed_device_user_agent:,
        disavowed_device_last_ip:,
        event_id:,
        event_type:,
        event_ip:,
        user_id:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Time, nil] event_created_at timestamp for the event
    # @param [Time, nil] disavowed_device_last_used_at
    # @param [String, nil] disavowed_device_user_agent
    # @param [String, nil] disavowed_device_last_ip
    # @param [Integer, nil] event_id events table id
    # @param [String, nil] event_type (see Event#event_type)
    # @param [String, nil] event_ip ip address for the event
    # An invalid disavowal token was clicked
    def event_disavowal_token_invalid(
      success:,
      error_details: nil,
      event_created_at: nil,
      disavowed_device_last_used_at: nil,
      disavowed_device_user_agent: nil,
      disavowed_device_last_ip: nil,
      event_id: nil,
      event_type: nil,
      event_ip: nil,
      **extra
    )
      track_event(
        'Event disavowal token invalid',
        success:,
        error_details:,
        event_created_at:,
        disavowed_device_last_used_at:,
        disavowed_device_user_agent:,
        disavowed_device_last_ip:,
        event_id:,
        event_type:,
        event_ip:,
        **extra,
      )
    end

    # @param [String] redirect_url URL user was directed to
    # @param [String, nil] step which step
    # @param [String, nil] location which part of a step, if applicable
    # @param ["idv", String, nil] flow which flow
    # User was redirected to a page outside the IDP
    def external_redirect(redirect_url:, step: nil, location: nil, flow: nil, **extra)
      track_event(
        'External Redirect',
        redirect_url: redirect_url,
        step: step,
        location: location,
        flow: flow,
        **extra,
      )
    end

    # @param [String] controller
    # @param [Boolean] user_signed_in
    # Authenticity token (CSRF) is invalid
    def invalid_authenticity_token(
      controller:,
      user_signed_in: nil,
      **extra
    )
      track_event(
        'Invalid Authenticity Token',
        controller: controller,
        user_signed_in: user_signed_in,
        **extra,
      )
    end

    # New device alert skipped as there were no events to send
    def new_device_alert_skipped(**extra)
      track_event(:new_device_alert_skipped, **extra)
    end

    # @param [String] location Placement location
    # Logged when a browser with JavaScript disabled loads the detection stylesheet
    def no_js_detect_stylesheet_loaded(location:, **extra)
      track_event(:no_js_detect_stylesheet_loaded, location:, **extra)
    end

    # Tracks the health of the DoS Passports API
    # @param [Boolean] success Whether the passport api health check succeeded.
    # @param [Hash] body The health check body, if present.
    # @param [Hash] errors Any additional error information we have
    # @param [String] step The step in the IdV flow that called the API health check
    # @param [String] exception The Faraday or other exception, if one happened
    def passport_api_health_check(
      success:,
      body: nil,
      errors: nil,
      exception: nil,
      step: nil,
      **extra
    )
      track_event(
        :passport_api_health_check,
        success:,
        body:,
        errors:,
        exception:,
        step:,
        **extra,
      )
    end

    # @param [String] redirect_url URL user was directed to
    # @param [String, nil] step which step
    # @param [String, nil] location which part of a step, if applicable
    # @param ["idv", String, nil] flow which flow
    # User was redirected to the login.gov policy page
    def policy_redirect(redirect_url:, step: nil, location: nil, flow: nil, **extra)
      track_event(
        'Policy Page Redirect',
        redirect_url: redirect_url,
        step: step,
        location: location,
        flow: flow,
        **extra,
      )
    end

    # Tracks when a user triggered a rate limiter
    # @param [String] limiter_type Name of the rate limiter configuration exceeded
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
    # @param ["authentication", "reauthentication", "confirmation"] context User session context
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [String,nil] step_name Name of step in user flow where rate limit occurred
    # @identity.idp.previous_event_name Throttler Rate Limit Triggered
    def rate_limit_reached(
      limiter_type:,
      country_code: nil,
      phone_fingerprint: nil,
      context: nil,
      otp_delivery_preference: nil,
      step_name: nil,
      **extra
    )
      track_event(
        'Rate Limit Reached',
        limiter_type:,
        country_code:,
        phone_fingerprint:,
        context:,
        otp_delivery_preference:,
        step_name:,
        **extra,
      )
    end

    # Rate limit triggered
    # @param [String] type
    def rate_limit_triggered(type:, **extra)
      track_event('Rate Limit Triggered', type: type, **extra)
    end

    # A response timed out
    # @param [String] backtrace
    # @param [String] exception_message
    # @param [String] exception_class
    def response_timed_out(
      backtrace:,
      exception_message:,
      exception_class:,
      **extra
    )
      track_event(
        'Response Timed Out',
        backtrace: backtrace,
        exception_message: exception_message,
        exception_class: exception_class,
        **extra,
      )
    end

    # Tracks when rules of use is submitted with a success or failure
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    def rules_of_use_submitted(success:, error_details: nil, **extra)
      track_event(
        'Rules of Use Submitted',
        success:,
        error_details:,
        **extra,
      )
    end

    # Tracks when rules of use is visited
    def rules_of_use_visit
      track_event('Rules of Use Visited')
    end

    # Tracks if the session is kept alive
    def session_kept_alive
      track_event('Session Kept Alive')
    end

    # Tracks if the session timed out
    def session_timed_out
      track_event('Session Timed Out')
    end

    # Tracks when a user's session is timed out
    def session_total_duration_timeout
      track_event('User Maximum Session Length Exceeded')
    end

    # Tracks when user clicks on same tab that user landed on.
    # @param [String, nil] path that user was on when navigation tab was clicked
    def tab_navigation_current_page_clicked(path: nil, **extra)
      track_event(:tab_navigation_current_page_clicked, path:, **extra)
    end

    # @param [String] controller
    # @param [String] referer
    # @param [Boolean] user_signed_in
    # Redirect was almost sent to an invalid external host unexpectedly
    def unsafe_redirect_error(
      controller:,
      referer:,
      user_signed_in: nil,
      **extra
    )
      track_event(
        'Unsafe Redirect',
        controller: controller,
        referer: referer,
        user_signed_in: user_signed_in,
        **extra,
      )
    end

    # @param [Hash] vendor_status
    # @param [String,nil] redirect_from
    # Tracks when vendor has outage
    def vendor_outage(
      vendor_status:,
      redirect_from: nil,
      **extra
    )
      track_event(
        'Vendor Outage',
        redirect_from: redirect_from,
        vendor_status: vendor_status,
        **extra,
      )
    end
  end
end
