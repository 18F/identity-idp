# frozen_string_literal: true

module AttemptsApi
  module TrackerEvents
    # @param [String] email The submitted email address
    # @param [Boolean] success True if the email and password matched
    # A user has submitted an email address and password for authentication
    def email_and_password_auth(email:, success:)
      track_event(
        'login-email-and-password-auth',
        email: email,
        success: success,
      )
    end
  end
end
