# Attempts to validate conformance to WCAG Success Criteria 2.4.2: Page Titled
#
# Visiting a page with the default app name title is considered a failure, and should be resolved by
# providing a distinct description for the page using the `:title` content block.
#
# https://www.w3.org/WAI/WCAG21/Understanding/page-titled.html

module PageTitled
  def visit(*args)
    super(*args)

    raise "Visited page '#{current_path}' without distinct title" if title&.strip == APP_NAME
  end
end

module Capybara
  class Session
    prepend PageTitled
  end
end
