require 'gmail'

class MonitorEmailHelper
  attr_reader :gmail

  def initialize(email:, password:, local:)
    @gmail = Gmail.connect!(email, password) unless local
    @local = local
  end

  def local?
    @local
  end

  def inbox_unread
    gmail.inbox.emails(:unread)
  end

  def inbox_clear
    inbox_unread.each(&:read!)
    gmail.inbox.emails(:read).each(&:delete!)
  end

  def scan_emails_and_extract(regex:, subject: nil)
    subjects = [*subject]

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match_data = body.match(regex))
        return to_local_url(match_data[1])
      end
    else
      check_and_sleep do
        inbox_unread.each do |email|
          if subjects.any?
            next unless subjects.include?(email.subject)
          end
          body = email.message.parts.first.body
          if (match_data = body.match(regex))
            email.read!
            return match_data[1]
          end
        end
        nil
      end
    end

    raise "failed to find email that matched #{regex}"
  end

  # local tests use "example.com" as the domain in emails but they actually
  # render on localhost, so we need to patch them to be relative
  def to_local_url(url)
    URI(url).tap do |uri|
      uri.scheme = nil
      uri.host = nil
    end.to_s
  end

  def check_and_sleep(count: 10, sleep_duration: 3)
    count.times do
      result = yield

      return result if result.present?

      sleep sleep_duration
    end
  end
end
