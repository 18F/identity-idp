# frozen_string_literal: true

module RuboCop
  module Cop
    module IdentityIdp
      # This linter checks to ensure that strings which include HTML are rendered using Rails `t`
      # view helper, rather than through the I18n class. Only the Rails view helper will mark the
      # content as HTML-safe.
      #
      # @see https://guides.rubyonrails.org/i18n.html#using-safe-html-translations
      #
      # @example
      #   # bad
      #   I18n.t('errors.message_html')
      #
      #   # good
      #   t('errors.message_html')
      #
      class I18nHelperHtmlLinter < RuboCop::Cop::Base
        MSG = 'Use the Rails `t` view helper for HTML-safe strings'

        RESTRICT_ON_SEND = [:t].freeze

        def_node_matcher :i18n_class_send?, <<~PATTERN
          (send (const nil? :I18n) :t $...)
        PATTERN

        def on_send(node)
          return if !i18n_class_send?(node) || !i18n_key(node)&.end_with?('_html')
          add_offense(node)
        end

        private

        def i18n_key(node)
          first_argument = node.arguments.first
          return if first_argument.nil?
          return if !first_argument.respond_to?(:value)
          first_argument.value.to_s
        end
      end
    end
  end
end
