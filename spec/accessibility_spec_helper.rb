require 'rails_helper'
require 'axe/rspec'

Capybara.default_driver = Capybara.javascript_driver

module PageIsAccessible
  include RSpec::Matchers

  def visit(*args)
    page.visit(*args)

    expect(page).to be_accessible.according_to :section508, :"best-practice"
    expect(page).to label_required_fields

    # TODO: Replace with a matcher
    # Visiting a page with the default app name title is considered a failure, and should be resolved by
    # providing a distinct description for the page using the `:title` content block.
    raise "Visited page '#{current_path}' without distinct title" if title&.strip == APP_NAME
  end
end

module Capybara
  module DSL
    prepend PageIsAccessible
  end
end
