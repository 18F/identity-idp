module RuboCop
  module Cop
    module IdentityIdp
      # This lint helps make sure that we have language-agnostic identifiers
      # for errors that we log. The error strings are different in each locale
      # so this helps us compare them more directly.
      #
      # @example
      #   #bad
      #   errors.add(:iss, 'invalid issuer')
      #
      #   #good
      #   errors.add(:iss, 'invalid issuer', type: :invalid_issuer)
      #
      class ErrorsAddLinter < RuboCop::Cop::Cop
        MSG = 'Please set a unique key for this error'.freeze

        RESTRICT_ON_SEND = [:add]

        def_node_matcher :errors_add_match?, <<~PATTERN
          (send (send nil? :errors) :add $...)
        PATTERN

        def on_send(node)
          unless node.arguments.last.type == :hash || errors_add_match?(node).nil?
            return add_offense(node, location: :expression)
          end
          errors_add_match?(node) do |arguments|
            type_node = arguments.last.pairs.find do |pair|
              pair.key.sym_type? && pair.key.source == 'type'
            end
            add_offense(node, location: :expression) unless type_node
          end
        end
      end
    end
  end
end
