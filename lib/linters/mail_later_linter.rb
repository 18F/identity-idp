module RuboCop
  module Cop
    module IdentityIdp
      # This lint ensures `deliver_later` is used to minimize the amount of work
      # in main IDP processes
      #
      # @example
      #   #bad
      #   UserMailer.signup_with_your_email(user, email).deliver_now
      #
      #   #good
      #   UserMailer.signup_with_your_email(user, email).deliver_later
      #     include Rails.application.routes.url_helpers
      #
      class MailLaterLinter < RuboCop::Cop::Cop
        MSG = 'Please send mail using deliver_later instead'.freeze

        RESTRICT_ON_SEND = [:deliver_now].freeze

        def on_send(node)
          add_offense(node, location: :expression)
        end
      end
    end
  end
end
