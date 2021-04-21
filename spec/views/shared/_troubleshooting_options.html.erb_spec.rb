require 'rails_helper'

describe 'shared/_troubleshooting_options.html.erb' do
  let(:heading) { '' }
  let(:heading_level) { nil }
  let(:options) { [] }

  before do
    render(
      'shared/troubleshooting_options',
      heading: heading,
      heading_level: heading_level,
      options: options,
    )
  end

  describe 'heading' do
    let(:heading) { 'Having trouble?' }

    it 'renders heading text' do
      expect(rendered).to have_text('Having trouble?')
    end
  end

  describe 'heading_level' do
    context 'omitted' do
      it 'renders with default heading_level h2' do
        expect(rendered).to have_css('h2')
      end
    end

    context 'given' do
      let(:heading_level) { :h3 }

      it 'renders with custom heading_level' do
        expect(rendered).to have_css('h3')
      end
    end
  end

  describe 'options' do
    let(:options) { [{ text: 'One', url: '#one' }, { text: 'Two', url: '#two' }] }

    it 'renders options as links' do
      expect(rendered).to have_css('a[href="#one"]', text: 'One')
      expect(rendered).to have_css('a[href="#two"]', text: 'Two')
    end
  end
end
