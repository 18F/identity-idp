require 'rails_helper'

RSpec.describe Extensions::CapybaraDetachedNodeRetry do
  let(:node) { Capybara::Node::Base.new(nil, nil) }
  let(:detached_node_error) do
    Selenium::WebDriver::Error::UnknownError.new(
      'unknown error: unhandled inspector error: ' \
      '{"code":-32000,"message":"Node with given id does not belong to the document"}',
    )
  end

  describe '#catch_error?' do
    it 'treats a chromedriver detached node error as retryable' do
      expect(node.send(:catch_error?, detached_node_error, [])).to eq(true)
    end

    it 'does not treat other unknown errors as retryable' do
      error = Selenium::WebDriver::Error::UnknownError.new('something else entirely')

      expect(node.send(:catch_error?, error, [])).to eq(false)
    end

    it 'still defers to the configured retryable errors' do
      error = Capybara::ElementNotFound.new

      expect(node.send(:catch_error?, error, [Capybara::ElementNotFound])).to eq(true)
      expect(node.send(:catch_error?, error, [])).to eq(false)
    end
  end
end
