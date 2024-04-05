# frozen_string_literal: true

module Idv
  module Resolution
    class IdentityResolver
      def initialize(
          plugins:
        )
        @plugins = plugins
      end

      def resolve_identity(
        input:
      )

        enumerator = plugins.each

        original_input = input
        final_result = Hash.new.freeze

        next_plugin = ->(result:, input:) do
          plugin = enumerator.next

          # next_plugin_proxy allows plugins to selectively overwrite elements.
          # For example, a plugin could do:
          #
          #  - `next_plugin.call` to invoke the next plugin with the original input + result
          #  - `next_plugin.call result: {...}` to override the result
          #  - `next_plugin.call my_key: "foo"` to add `my_key` to the result
          #

          next_plugin_proxy = ->(input: nil, result: nil, **kwargs) do
            if result.nil?
              if kwargs.any?
                final_result = final_result.merge(kwargs).freeze
              end
            else
              if kwargs.any?
                raise "Can't specify result: and additional arguments"
              end
              final_result = result.freeze
            end

            next_plugin.call(
              input: input || original_input,
              result: final_result,
            )
          end

          plugin.resolve_identity(
            input:,
            result:,
            next_plugin: next_plugin_proxy,
          )
        rescue StopIteration
          return result
        end

        next_plugin.call(
          result: final_result,
          input:,
        )
      end

      private

      attr_reader :plugins
    end
end
end
