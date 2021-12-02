require 'rails_helper'

describe 'shared/_troubleshooting_options.html.erb' do
  let(:heading) { '' }
  let(:heading_tag) { nil }
  let(:options) { [{ text: 'One', url: '#one' }, { text: 'Two', url: '#two' }] }
  let(:classes) { nil }

  before do
    render(
      'shared/troubleshooting_options',
      heading: heading,
      heading_tag: heading_tag,
      options: options,
      class: classes,
    )
  end

  describe 'heading' do
    let(:heading) { 'Having trouble?' }

    it 'renders heading text' do
      expect(rendered).to have_text('Having trouble?')
    end
  end

  describe 'heading_tag' do
    context 'omitted' do
      it 'renders with default heading_tag h2' do
        expect(rendered).to have_css('h2')
      end
    end

    context 'given' do
      let(:heading_tag) { :h3 }

      it 'renders with custom heading_tag' do
        expect(rendered).to have_css('h3')
      end
    end
  end

  describe 'options' do
    context 'without any options' do
      let(:options) { [] }

      it 'does not render anything' do
        expect(rendered).to be_empty
      end
    end

    context 'with options' do
      it 'renders options as links' do
        expect(rendered).to have_css('a[href="#one"]', text: 'One')
        expect(rendered).to have_css('a[href="#two"]', text: 'Two')
      end
    end
  end

  describe 'options' do
    context 'without custom class' do
      it 'renders default css class' do
        expect(rendered).to have_css('.troubleshooting-options')
      end
    end

    context 'with custom class' do
      let(:classes) { 'my-custom-class' }

      it 'renders with default and custom css classes' do
        expect(rendered).to have_css('.troubleshooting-options.my-custom-class')
      end
    end
  end
end
