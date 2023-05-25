module JobHelpers
  module UspsProofingResultsJob
    module EmailHelper
      def send_verified_email(user, enrollment)
        user.confirmed_email_addresses.each do |email_address|
          # rubocop:disable IdentityIdp/MailLaterLinter
          UserMailer.with(user: user, email_address: email_address).in_person_verified(
            enrollment: enrollment,
          ).deliver_later(**mail_delivery_params(enrollment.proofed_at))
          # rubocop:enable IdentityIdp/MailLaterLinter
        end
      end

      def send_deadline_passed_email(user, enrollment)
        # rubocop:disable IdentityIdp/MailLaterLinter
        user.confirmed_email_addresses.each do |email_address|
          UserMailer.with(user: user, email_address: email_address).in_person_deadline_passed(
            enrollment: enrollment,
          ).deliver_later
          # rubocop:enable IdentityIdp/MailLaterLinter
        end
      end

      def send_failed_email(user, enrollment)
        user.confirmed_email_addresses.each do |email_address|
          # rubocop:disable IdentityIdp/MailLaterLinter
          UserMailer.with(user: user, email_address: email_address).in_person_failed(
            enrollment: enrollment,
          ).deliver_later(**mail_delivery_params(enrollment.proofed_at))
          # rubocop:enable IdentityIdp/MailLaterLinter
        end
      end

      def send_failed_fraud_email(user, enrollment)
        user.confirmed_email_addresses.each do |email_address|
          # rubocop:disable IdentityIdp/MailLaterLinter
          UserMailer.with(user: user, email_address: email_address).in_person_failed_fraud(
            enrollment: enrollment,
          ).deliver_later(**mail_delivery_params(enrollment.proofed_at))
          # rubocop:enable IdentityIdp/MailLaterLinter
        end
      end

      def mail_delivery_params(proofed_at)
        return {} if proofed_at.blank?
        mail_delay_hours = IdentityConfig.store.in_person_results_delay_in_hours ||
                          DEFAULT_EMAIL_DELAY_IN_HOURS
        wait_until = proofed_at + mail_delay_hours.hours
        return {} if mail_delay_hours == 0 || wait_until < Time.zone.now
        return { wait_until: wait_until, queue: :intentionally_delayed }
      end
    end
  end
end
