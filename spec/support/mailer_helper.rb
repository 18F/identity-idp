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

  def expect_delivered_email(index, hash)
    mail = ActionMailer::Base.deliveries[index]

    aggregate_failures do
      expect(mail.to).to eq hash[:to] if hash[:to]
      expect(mail.subject).to eq hash[:subject] if hash[:subject]

      if hash[:body]
        delivered_body = mail.text_part.decoded.gsub("\r\n", ' ')
        hash[:body].to_a.each do |expected_body|
          expect(delivered_body).to include(expected_body)
        end
      end
    end
  end
end
