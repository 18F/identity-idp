module AnalyticsEvents
  # @identity.idp.event_name Account Reset
  # @param [Boolean] success
  # @param ["cancel", "delete", "cancel token validation", "granted token validation", :notifications] event
  # @param [String] message_id Request ID from AWS Pinpoint API
  # @param [String] request_id Request ID from AWS Pinpoint API
  # @param [Boolean] sms_phone
  # @param [Boolean] totp does the user have an authentication app as a 2FA option?
  # @param [Boolean] piv_cac does the user have PIV/CAC as a 2FA option?
  # @param [Integer] count number of notifications sent
  # @param [Hash] errors
  # @param [String] user_id
  # @param [Integer] account_age_in_days
  # @param [Hash] mfa_method_counts
  # Tracks events related to a user requesting to delete their account during the sign in process
  # (because they have no other means to sign in).
  def account_reset(
    success: nil,
    event: nil,
    message_id: nil,
    piv_cac: nil,
    request_id: nil,
    sms_phone: nil,
    totp: nil,
    count: nil,
    errors: nil,
    user_id: nil,
    account_age_in_days: nil,
    mfa_method_counts: nil,
    pii_like_keypaths: nil,
    error_details: nil,
    email_addresses: nil
  )
    track_event(
      'Account Reset',
      {
        success: success,
        event: event,
        message_id: message_id,
        piv_cac: piv_cac,
        request_id: request_id,
        sms_phone: sms_phone,
        totp: totp,
        count: count,
        errors: errors,
        user_id: user_id,
        account_age_in_days: account_age_in_days,
        mfa_method_counts: mfa_method_counts,
        pii_like_keypaths: pii_like_keypaths,
        error_details: error_details,
        email_addresses: email_addresses,
      }.compact,
    )
  end
end
