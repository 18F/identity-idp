require 'rails_helper'

RSpec.describe ButtonComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  let(:type) { nil }
  let(:outline) { false }
  let(:content) { 'Button' }
  let(:options) do
    {
      type: type,
    }.compact
  end

  subject(:rendered) do
    render_inline ButtonComponent.new(outline: outline, **options).with_content(content)
  end

  it 'renders button content' do
    expect(rendered).to have_content(content)
  end

  it 'renders as type=button' do
    expect(rendered).to have_css('button[type=button]')
  end

  it 'renders with design system classes' do
    expect(rendered).to have_css('button.usa-button')
  end

  context 'with outline' do
    let(:outline) { true }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--outline')
    end
  end

  context 'with type' do
    let(:type) { :submit }

    it 'renders as type' do
      expect(rendered).to have_css('button[type=submit]')
    end
  end

  context 'with icon' do
    it 'renders an icon' do
      rendered = render_inline ButtonComponent.new(icon: :print).with_content(content)

      expect(rendered).to have_css('use[href$="#print"]')
      expect(rendered.first_element_child.xpath('./text()').text).to eq(content)
    end
  end

  context 'with custom button action' do
    it 'calls the action with content and tag_options' do
      rendered = render_inline ButtonComponent.new(
        action: ->(content, **tag_options) do
          content_tag(:'lg-custom-button', **tag_options, data: { extra: '' }) { content }
        end,
        class: 'custom-class',
      ).with_content(content)

      expect(rendered).to have_css(
        'lg-custom-button[type="button"][data-extra].custom-class',
        text: content,
      )
    end
  end
end
