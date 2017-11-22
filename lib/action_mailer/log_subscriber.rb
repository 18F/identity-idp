# By default, when emails are delivered via ActiveJob, the recipients' email
# is logged in a line like "Sent mail to test@test.com". Rails does not provide
# an easy way to filter out emails from the logs. To protect user privacy, we
# want to remove user emails from the logs, and the only way to do it is to
# override the `deliver` method below such that it doesn't log anything.
module ActionMailer
  class LogSubscriber < ActiveSupport::LogSubscriber
    def deliver(_event); end
  end
end
