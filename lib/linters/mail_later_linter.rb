module RuboCop
  module Cop
    module IdentityIdp
      # This lint ensures `deliver_now_or_later` is used so that we can consistently
      # use either sync or async delivery depending on a feature flag
      #
      # @example
      #   #bad
      #   UserMailer.signup_with_your_email(user, email).deliver_now
      #   UserMailer.signup_with_your_email(user, email).deliver_later
      #
      #   #good
      #   UserMailer.signup_with_your_email(user, email).deliver_now_or_later
      #   UserMailer.with(params).signup_with_your_email(user, email).deliver_now_or_later
      #   ReportMailer.report_mail(data).deliver_now
      #
      class MailLaterLinter < RuboCop::Cop::Cop
        MSG = 'Please send mail using deliver_now_or_later instead'.freeze

        RESTRICT_ON_SEND = [:deliver_now, :deliver_later].freeze

        def on_send(node)
          receiver = node.children.first&.receiver
          return if !receiver

          mailer_name = if receiver.const_type?
                          # MailerClass.email.send_later
                          receiver.const_name
                        elsif receiver.method_name == :with
                          # MailerClass.with(...).email.send_later
                          receiver.receiver.const_name
                        end

          add_offense(node, location: :expression) if mailer_name == 'UserMailer'
        end
      end
    end
  end
end
