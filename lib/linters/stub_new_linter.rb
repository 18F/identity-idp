module RuboCop
  module Cop
    module IdentityIdp
      class StubNewLinter < RuboCop::Cop::Cop
        MSG = 'Please avoid stubbing Class::new'.freeze

        RESTRICT_ON_SEND = [:receive]

        def_node_matcher :receive_new_matcher, <<~PATTERN
          (send nil? :receive (sym :new))
        PATTERN

        def on_send(node)
          receive_new_matcher(node) do
            add_offense(node, location: :expression)
          end
        end
      end
    end
  end
end
