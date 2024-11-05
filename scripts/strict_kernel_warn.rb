# frozen_string_literal: true

module Kernel
  prepend(
    Module.new do
      def warn(*msgs)
        super("Error: Unexpected warn logging occurred:\n\n#{msgs.join("\n\n")}")
        exit! 1
      end
    end,
  )
end
