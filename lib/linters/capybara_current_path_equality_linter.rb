# frozen_string_literal: true

module RuboCop
  module Cop
    module IdentityIdp
      # This lint is similar to
      # https://docs.rubocop.org/rubocop-capybara/cops_capybara.html#capybaracurrentpathexpectation
      # and our `IdentityIdp::CapybaraCurrentUrlExpectLinter` in that it is intended to help prevent
      # race conditions. A comparison of the `current_path` or `current_url` relies on page
      # navigation timing which can be asynchronous and lead to inconsistent results.
      #
      # These cases typically come up when trying to support multiple action paths in a feature
      # test. We should prefer being explicit about what actions are expected rather than relying
      # on changing a shared helper, even if it results in a more verbose test.
      # Using method parameters to control the flow is another option. The critical part is the
      # conditional should be stable regardless of the timing of browser activity.
      #
      # @example
      #   #bad
      #   return if page.current_path == idv_document_capture_path
      #
      class CapybaraCurrentPathEqualityLinter < RuboCop::Cop::Base
        include RangeHelp

        MSG = 'Do not compare equality of `current_path` in Capybara feature specs - instead,' \
        ' use the `have_current_path` matcher on `page` or avoid it entirely'

        RESTRICT_ON_SEND = %i[== !=].freeze

        def_node_matcher :current_path_equality_lhs, <<~PATTERN
          (send (send {(send nil? :page) nil?} :current_path) ${:== :!=} (...))
        PATTERN

        def_node_matcher :current_path_equality_rhs, <<~PATTERN
          (send (...) ${:== :!=} (send {(send nil? :page) nil?} :current_path))
        PATTERN

        def on_send(node)
          if current_path_equality_lhs(node) || current_path_equality_rhs(node)
            add_offense(node)
          end
        end
      end
    end
  end
end
