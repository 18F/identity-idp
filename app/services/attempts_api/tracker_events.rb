# frozen_string_literal: true

module AttemptsApi
  module TrackerEvents
    # @param [Boolean] success True if the email and password matched
    # A user has submitted an email address and password for authentication
    def email_and_password_auth(success:)
      track_event(
        'login-email-and-password-auth',
        success: success,
      )
    end
  end
end
