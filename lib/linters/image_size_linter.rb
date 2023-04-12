module RuboCop
  module Cop
    module IdentityIdp
      # This lint ensures that images rendered with Rails tag helpers include a size attribute
      # (`width` and `height`, or `size`), which is a best practice to avoid layout shifts.
      #
      # @see https://web.dev/optimize-cls/#images-without-dimensions
      #
      # @example
      #   # bad
      #   image_tag 'example.svg'
      #
      #   # good
      #   image_tag 'example.svg', width: 10, height: 20
      #
      class ImageSizeLinter < RuboCop::Cop::Cop
        MSG = 'Assign width and height to images'.freeze

        RESTRICT_ON_SEND = [:image_tag]

        def on_send(node)
          add_offense(node, location: :expression) if !valid?(node)
        end

        private

        def valid?(node)
          options = node.arguments.last
          return false if options.type != :hash
          return true if options.child_nodes.any? { |child_node| child_node.type == :kwsplat }
          key_names = options.keys.map { |key| key.value }
          key_names.include?(:size) || (key_names.include?(:width) && key_names.include?(:height))
        end
      end
    end
  end
end
