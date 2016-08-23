require 'rails_helper'

describe ApplicationHelper do
  describe '#tooltip' do
    it 'creates a span containing aria label with text and image' do
      tooltip_text = 'foobar'

      html = helper.tooltip(tooltip_text)

      expect(html).to have_css('.hint--top')
      expect(html).to have_selector('img')
      expect(html).to have_xpath("//span[@aria-label='#{tooltip_text}']")
    end
  end
end
