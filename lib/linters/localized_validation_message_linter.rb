# frozen_string_literal: true

module RuboCop
  module Cop
    module IdentityIdp
      class LocalizedValidationMessageLinter < RuboCop::Cop::Cop
        MSG = 'Use proc when translating validation message'

        RESTRICT_ON_SEND = [
          :validate,
          :validates,
          :validates!,
          :validates_with,
          :validates_absence_of,
          :validates_acceptance_of,
          :validates_confirmation_of,
          :validates_exclusion_of,
          :validates_format_of,
          :validates_inclusion_of,
          :validates_length_of,
          :validates_numericality_of,
          :validates_presence_of,
          :validates_size_of,
        ].freeze

        def_node_matcher :translated_validation_message?, <<~PATTERN
          (send nil? /^validate|validates|validates!$/ _ (hash (pair _ (hash (pair (sym :message) (send (const nil? :I18n) :t ...))))))
        PATTERN

        def_node_matcher :translated_validation_helper_message?, <<~PATTERN
          (send nil? /^validates_.+_of$/ _ (hash (pair (sym :message) (send (const nil? :I18n) :t ...))))
        PATTERN

        def on_send(node)
          if translated_validation_message?(node) || translated_validation_helper_message?(node)
            add_offense(node, location: :expression)
          end
        end
      end
    end
  end
end
