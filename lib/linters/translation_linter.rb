module RuboCop
  module Cop
    module IdentityIdp
      # This lint prevents the use of Rails translation method, and is intended only to be applied
      # on files where localization is not available (e.g. smoke tests).
      class TranslationLinter < RuboCop::Cop::Cop
        MSG = 'Translation is not allowed in this file'.freeze

        RESTRICT_ON_SEND = [:t].freeze

        def on_send(node)
          add_offense(node, location: :expression)
        end
      end
    end
  end
end
