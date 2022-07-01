module RuboCop
  module Cop
    module IdentityIdp
      # This lint ensures `url_options` is defined in classes that have
      # `include Rails.application.routes.url_helpers`. Including `url_helpers`
      # without defining url_options loses information from the HTTP request
      # that helps build internationalization-friendly URLs.
      #
      # @example
      #   #bad
      #   class MyViewModelClass
      #     include Rails.application.routes.url_helpers
      #
      #     def my_method
      #       account_path
      #     end
      #   end
      #
      #   #good
      #   class MyViewModelClass
      #     include Rails.application.routes.url_helpers
      #
      #     attr_reader :url_options
      #
      #     def initialize(url_options)
      #       @url_options = url_options
      #     end
      #
      #     def my_method
      #       account_path
      #     end
      #   end
      #
      class UrlOptionsLinter < RuboCop::Cop::Cop
        MSG = 'Please define url_options when including Rails.application.routes.url_helpers'.freeze

        RESTRICT_ON_SEND = [:include].freeze

        # This matcher checks for a call to `include Rails.application.routes.url_helpers`
        def_node_matcher :includes_url_helpers?, <<~PATTERN
          (send nil? :include (send (send (send (const nil? :Rails) :application) :routes) :url_helpers))
        PATTERN

        def on_send(node)
          return unless includes_url_helpers?(node)
          return if defines_url_options?(node)

          add_offense(node, location: :expression)
        end

        private

        # Borrowed logic from:
        # https://github.com/rubocop-hq/rubocop/blob/751edc7/lib/rubocop/cop/style/missing_respond_to_missing.rb#L38-L49
        def defines_url_options?(node)
          node.parent.each_descendant(:def) do |descendant|
            return true if descendant.method?(:url_options)
          end

          node.parent.each_descendant(:send) do |descendant|
            return true if url_options_attr_method?(descendant)
          end

          false
        end

        def url_options_attr_method?(descendant)
          return false unless descendant.method_name.match?(/^attr_(reader|accessor)$/)
          descendant.arguments.any? { |arg| arg.value == :url_options }
        end
      end
    end
  end
end
