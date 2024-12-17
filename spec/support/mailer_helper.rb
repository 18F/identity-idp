module MailerHelper
  def last_email
    ActionMailer::Base.deliveries.last
  end

  def reset_email
    ActionMailer::Base.deliveries = []
  end

  def expect_delivered_email_count(count)
    expect(ActionMailer::Base.deliveries.count).to eq count
  end

  def strip_tags(str)
    ActionController::Base.helpers.strip_tags(str)
  end

  # @param [String,String[],nil] to The email address(es) the message must've been sent to.
  # @param [String,nil] subject The subject the email must've had
  # @param [String[],nil] Array of substrings that must appear in body.
  def expect_delivered_email(to: nil, subject: nil, body: nil)
    email = find_sent_email(to:, subject:, body:)

    error_message = <<~ERROR
      Unable to find email matching args:
        to: #{to}
        subject: #{subject}
        body: #{body}
      Sent mails:
      #{summarize_all_deliveries(to:, subject:, body:).indent(2)}
    ERROR

    expect(email).to_not be(nil), error_message
  end

  private

  def body_matches(email:, body:)
    return true if body.nil?

    delivered_body = email.text_part.decoded.squish

    Array.wrap(body).all? do |expected_substring|
      delivered_body.include?(expected_substring)
    end
  end

  def to_matches(email:, to:)
    return true if to.nil?

    to = Array.wrap(to).to_set

    (email.to.to_set - to).empty?
  end

  def find_sent_email(
    to:,
    subject:,
    body:
  )
    ActionMailer::Base.deliveries.find do |email|
      to_ok = to_matches(email:, to:)
      subject_ok = subject.nil? || email.subject == subject
      body_ok = body_matches(email:, body:)

      to_ok && subject_ok && body_ok
    end
  end

  def summarize_delivery(
    email:,
    to:,
    subject:,
    body:
  )
    body_text = email.text_part.decoded.squish

    body_summary = body.presence && Array.wrap(body).map do |substring|
      found = body_text.include?(substring)
      "- #{substring.inspect} (#{found ? 'found' : 'not found'})"
    end.join("\n")

    to_ok = to_matches(email:, to:)
    subject_ok = subject.nil? || subject == email.subject

    [
      "To:      #{email.to}#{to_ok ? '' : ' (did not match)'}",
      "Subject: #{email.subject}#{subject_ok ? '' : ' (did not match)'}",
      body.presence && "Body:\n#{body_summary.indent(2)}",
    ].compact.join("\n")
  end

  def summarize_all_deliveries(query)
    ActionMailer::Base.deliveries.map do |email|
      summary = summarize_delivery(email:, **query)
      [
        "- #{summary.lines.first.chomp}",
        *summary.lines.drop(1).map { |l| l.chomp.indent(2) },
      ].join("\n")
    end.join("\n")
  end
end
