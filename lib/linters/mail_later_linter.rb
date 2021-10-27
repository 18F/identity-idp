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
      #
      class MailLaterLinter < RuboCop::Cop::Cop
        MSG = 'Please send mail using deliver_now_or_later instead'.freeze

        RESTRICT_ON_SEND = [:deliver_now, :deliver_later].freeze

        def on_send(node)
          add_offense(node, location: :expression)
        end
      end
    end
  end
end
