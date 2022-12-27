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

  def expect_delivered_email(to: nil, subject: nil, body: nil)
    email = ActionMailer::Base.deliveries.find do |sent_mail|
      next unless to.present? && sent_mail.to == to
      next unless subject.present? && sent_mail.subject == subject
      if body.present?
        delivered_body = sent_mail.text_part.decoded.squish
        body.to_a.each do |expected_body|
          next unless delivered_body.include?(expected_body)
        end
      end
      true
    end

    error_message = <<~ERROR
      Unable to find email matching args:
        to: #{to}
        subject: #{subject}
        body: #{body}
      Sent mails: #{ActionMailer::Base.deliveries}
    ERROR
    expect(email).to_not be(nil), error_message
  end
end
