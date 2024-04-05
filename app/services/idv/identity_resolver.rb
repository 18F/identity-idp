# frozen_string_literal: true

module Idv
  class IdentityResolver
    def initialize(
        plugins:
      )
      @plugins = plugins
    end

    def resolve_identity(
        pii_from_doc:,
        pii_from_user: nil
      )

      enumerator = plugins.each

      original_pii_from_doc = pii_from_doc.freeze
      original_pii_from_user = pii_from_user.freeze
      final_result = Hash.new.freeze

      next_plugin = ->(next_plugin:, result: nil, pii_from_doc: nil, pii_from_user: nil) do
        plugin = enumerator.next

        # next_plugin_proxy allows plugins to selectively overwrite elements.
        # For example, a plugin could do:
        #
        #  - `next_plugin.call` to invoke the next plugin with the original input + result
        #  - `next_plugin.call result: {...}` to override the result
        #

        next_plugin_proxy = ->(pii_from_doc: nil, pii_from_user: nil, result: nil) do
          final_result = final_result.merge(result).freeze if result

          next_plugin.call(
            pii_from_doc: pii_from_doc || original_pii_from_doc,
            pii_from_user: pii_from_user || original_pii_from_user,
            result: final_result,
            next_plugin: next_plugin_proxy,
          )
        end

        plugin.resolve_identity(
          pii_from_doc:,
          pii_from_user:,
          result:,
          next_plugin: next_plugin_proxy,
        )
      rescue StopIteration
        return result
      end

      next_plugin.call(
        result: final_result,
        pii_from_doc:,
        pii_from_user:,
        next_plugin:,
      )
    end

    private

    attr_reader :plugins
  end
end
