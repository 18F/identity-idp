# frozen_string_literal: true

module RuboCop
  module Cop
    module IdentityIdp
      class AnalyticsEventNameLinter < RuboCop::Cop::Cop
        RESTRICT_ON_SEND = [:track_event]

        def on_send(node)
          first_argument, = node.arguments
          expected_name = ancestor_method_name(node)
          if first_argument.type != :sym || first_argument.value != expected_name
            add_offense(
              first_argument,
              location: :expression,
              message: "Event name must match the method name, expected `:#{expected_name}`",
            )
          end
        end

        private

        def ancestor_method_name(node)
          node.each_ancestor(:def).first.method_name
        end
      end
    end
  end
end
