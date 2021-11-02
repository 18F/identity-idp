require 'aws-sdk-s3'
require 'mail'

class MonitorEmailHelper
  attr_reader :email

  def initialize(email:, local:, s3_bucket:, s3_prefix:)
    @email = email
    @s3_bucket = s3_bucket
    @s3_prefix = s3_prefix
    @local = local
  end

  def local?
    @local
  end

  def find_in_inbox(regex:, subjects:, email_address:)
    s3 = Aws::S3::Client.new
    s3_response = s3.list_objects(bucket: @s3_bucket, prefix: @s3_prefix, max_keys: 1_000)

    loop do
      objects = s3_response.contents.sort_by { |x| x.last_modified.to_i }.reverse

      objects.each do |x|
        object = begin
                   s3.get_object(bucket: @s3_bucket, key: x.key)
        rescue Aws::S3::Errors::AccessDenied
                   nil
        end

        next if object.nil?
        body = object.body.read
        mail = Mail.new(body)
        next unless mail.to&.any? { |x| x.include?(email_address) }
        next unless subjects.blank? || subjects.include?(mail.subject)
        match_data = mail.text_part.to_s.match(regex)
        next unless match_data
        s3.delete_object(bucket: @s3_bucket, key: x.key)
        return match_data[1]
      end

      break unless s3_response.next_page?
      s3_response = s3_response.next_page
    end

    nil
  end

  def scan_emails_and_extract(regex:, email_address:, subject: nil)
    subjects = [*subject]

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match_data = body.match(regex))
        return to_local_url(match_data[1])
      end
    else
      check_and_sleep do
        result = find_in_inbox(regex: regex, subjects: subjects, email_address: email_address)
        return result if result.present?
      end
    end

    raise "failed to find email to #{email_address} that matched #{regex}"
  end

  # local tests use "example.com" as the domain in emails but they actually
  # render on localhost, so we need to patch them to be relative
  def to_local_url(url)
    URI(url).tap do |uri|
      uri.scheme = nil
      uri.host = nil
    end.to_s
  end

  def check_and_sleep(count: 15, sleep_duration: 3)
    count.times do
      result = yield

      return result if result.present?

      sleep sleep_duration
    end
  end
end
