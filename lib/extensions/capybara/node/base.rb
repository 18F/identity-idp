# frozen_string_literal: true

# Monkey-patch Capybara::Node::Base#catch_error? to retry on chromedriver's detached node error.
#
# When the DOM is replaced between Capybara locating an element and inspecting it (for example a
# page navigation racing a visibility check), chromedriver is expected to raise
# StaleElementReferenceError, which Capybara treats as retryable inside `synchronize`. Recent
# Chrome versions instead surface a generic UnknownError whose message is "Node with given id
# does not belong to the document". Capybara does not recognise that as a stale element and fails
# immediately, which shows up as intermittent feature spec failures. Treat it as the stale element
# error it is so the surrounding wait retries.
#
# See: https://github.com/teamcapybara/capybara/blob/master/lib/capybara/node/base.rb

module Extensions
  module CapybaraDetachedNodeRetry
    DETACHED_NODE_MESSAGE = 'Node with given id does not belong to the document'

    def self.detached_node_error?(error)
      error.is_a?(::Selenium::WebDriver::Error::UnknownError) &&
        error.message.include?(DETACHED_NODE_MESSAGE)
    end

    private

    def catch_error?(error, errors = nil)
      super || CapybaraDetachedNodeRetry.detached_node_error?(error)
    end
  end

  Capybara::Node::Base.prepend(CapybaraDetachedNodeRetry)
end
