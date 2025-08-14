# frozen_string_literal: true

module RuboCop
  module Cop
    module IdentityIdp
      # This lint is a very similar to
      # https://docs.rubocop.org/rubocop-capybara/cops_capybara.html#capybaracurrentpathexpectation
      # but for `current_url` instead of `current_path`. The reasoning is the same in that it
      # ensures usage of Capybara's waiting functionality. This linter is not autocorrectable.
      #
      # @example
      #   #bad
      #   expect(current_url).to eq authentication_methods_setup_url
      #   expect(current_url).to eq 'http://localhost:3001/auth/result'
      #
      #   #good
      #   expect(page).to have_current_path(authentication_methods_setup_path)
      #   expect(page).to have_current_path('http://localhost:3001/auth/result', url: true)
      #
      class CapybaraCurrentUrlExpectLinter < RuboCop::Cop::Base
        include RangeHelp

        MSG = 'Do not set an RSpec expectation on `current_url` in ' \
          'Capybara feature specs - instead, use the ' \
          '`have_current_path` matcher on `page`'

        RESTRICT_ON_SEND = %i[expect].freeze

        # @!method expectation_set_on_current_url(node)
        def_node_matcher :expectation_set_on_current_url, <<~PATTERN
          (send nil? :expect (send {(send nil? :page) nil?} :current_url))
        PATTERN

        # Supported matchers: eq(...) / match(/regexp/) / match('regexp')
        # @!method as_is_matcher(node)
        def_node_matcher :as_is_matcher, <<~PATTERN
          (send
            #expectation_set_on_current_url ${:to :to_not :not_to}
            ${(send nil? :eq ...) (send nil? :match (...)) (send nil? :include ...) (send nil? :start_with ...)})
        PATTERN

        # @!method regexp_node_matcher(node)
        def_node_matcher :regexp_node_matcher, <<~PATTERN
          (send
           #expectation_set_on_current_url ${:to :to_not :not_to}
           $(send nil? :match ${str dstr xstr}))
        PATTERN

        def on_send(node)
          expectation_set_on_current_url(node) do
            as_is_matcher(node.parent) do
              add_offense(node.parent.loc.selector)
            end

            regexp_node_matcher(node.parent) do
              add_offense(node.parent.loc.selector)
            end
          end
        end
      end
    end
  end
end
