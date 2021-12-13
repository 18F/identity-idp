module RuboCop
  module Cop
    module IdentityIdp
      # This lint ensures `redirect_back` is called with
      # the fallback_location option and allow_other_host set to false.
      # This is to prevent open redirects via the Referer header.
      #
      # @example
      #   #bad
      #   redirect_back
      #   redirect_back '/'
      #   redirect_back allow_other_host: false
      #
      #   #good
      #   redirect_back fallback_location: '/', allow_other_host: false
      #
      class ErrorsAddLinter < RuboCop::Cop::Cop
        MSG = 'Please set a unique key for this error'.freeze

        RESTRICT_ON_SEND = [:add]

        def_node_matcher :errors_add_match?, <<~PATTERN
          (send (send nil? :errors) :add $...)
        PATTERN

        def on_send(node)
          # require 'pry'
          # binding.pry
          return unless errors_add_match?(node)
          add_offense(node, location: :expression)
        end
      end
    end
  end
end
