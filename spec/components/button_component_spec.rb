require 'rails_helper'

RSpec.describe ButtonComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  let(:options) { {} }
  let(:content) { 'Button' }

  subject(:rendered) do
    render_inline ButtonComponent.new(**options).with_content(content)
  end

  it 'renders button content' do
    expect(rendered).to have_content(content)
  end

  it 'renders with design system classes' do
    expect(rendered).to have_css('button.usa-button')
  end

  context 'with outline' do
    let(:options) { { outline: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--outline')
    end
  end

  context 'as big' do
    let(:options) { { big: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--big')
    end
  end

  context 'as wide' do
    let(:options) { { wide: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--wide')
    end
  end

  context 'as full width' do
    let(:options) { { full_width: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--full-width')
    end
  end

  context 'as unstyled' do
    let(:options) { { unstyled: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--unstyled')
    end
  end

  context 'as dangerous' do
    let(:options) { { danger: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--danger')
    end
  end

  context 'with tag options' do
    it 'renders as attributes' do
      rendered = render_inline ButtonComponent.new(
        type: :button,
        class: 'my-custom-class',
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('.usa-button.my-custom-class[type="button"][data-foo="bar"]')
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
        action: ->(**tag_options, &block) do
          content_tag(:'lg-custom-button', **tag_options, data: { extra: '' }, &block)
        end,
        class: 'custom-class',
      ).with_content(content)

      expect(rendered).to have_css(
        'lg-custom-button[data-extra].custom-class',
        text: content,
      )
    end
  end
end
