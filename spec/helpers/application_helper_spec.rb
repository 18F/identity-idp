require 'rails_helper'

describe ApplicationHelper do
  describe '#step_class' do
    it 'creates CSS class based on current and active step' do
      expect(helper.step_class(1, 2)).to eq 'complete'
      expect(helper.step_class(2, 2)).to eq 'active'
      expect(helper.step_class(2, 1)).to be_nil
    end
  end

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
