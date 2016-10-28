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

  describe '#decorated_session' do
    context 'with service provider' do
      it 'returns the service provider decorator' do
        @sp_name = 'any sp'

        expect(helper.decorated_session).to be_an_instance_of(
          ServiceProviderSessionDecorator
        )
      end
    end

    context 'without service provider' do
      it 'returns the regular sessiin decorator' do
        @sp_name = nil

        expect(helper.decorated_session).to be_an_instance_of(SessionDecorator)
      end
    end
  end
end
