#
# Use this matcher in any test that has access to a Capybara page object (a.k.a. Capybara::Session)
# ... to test whether some content appears before some other content on the page.
# ... source: https://stackoverflow.com/a/14769902
#
# @param [String] earlier_content some text on the page expected to appear first
# @param [String] later_content some text on the page expected to appear last
#
# @example
#
# it "ensures proper order of page contents" do
#   expect("Hello").to appear_before("World")
# end
#
RSpec::Matchers.define :appear_before do |later_content|
  match do |earlier_content|
    page.body.index(earlier_content) < page.body.index(later_content)
  end
end
