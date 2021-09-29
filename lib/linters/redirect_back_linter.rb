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
      class RedirectBackLinter < RuboCop::Cop::Cop
        MSG = 'Please set a fallback_location and the allow_other_host parameter to false'.freeze

        RESTRICT_ON_SEND = [:redirect_back]

        def_node_matcher :redirect_back_matcher, <<~PATTERN
          (send nil? :redirect_back $...)
        PATTERN

        def on_send(node)
          add_offense(node, location: :expression) && return if node.arguments.empty?

          sets_fallback_location, sets_allow_other_host_false = false
          redirect_back_matcher(node) do |arguments|
            arguments.first.pairs.each do |pair|
              if pair.key.sym_type? && pair.key.source == 'fallback_location' &&
                 !pair.value.source.nil?
                sets_fallback_location = true
              end

              if pair.key.sym_type? && pair.key.source == 'allow_other_host' &&
                 pair.value.false_type?
                sets_allow_other_host_false = true
              end
            end
          end

          return if sets_fallback_location && sets_allow_other_host_false

          add_offense(node, location: :expression)
        end
      end
    end
  end
end
