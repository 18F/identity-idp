require 'rails_helper'

RSpec.describe IconListComponent, type: :component do
  subject(:rendered) { render_inline IconListComponent.new }

  it 'renders with expected attributes for default state' do
    expect(rendered).to have_css('.usa-icon-list.usa-icon-list--size-md')
  end

  context 'with explicitly nil size' do
    subject(:rendered) { render_inline IconListComponent.new(size: nil) }

    it 'renders without size modifier css class' do
      expect(rendered).not_to have_css('[class*=usa-icon-list--size-]')
    end
  end

  context 'with additional tag options' do
    subject(:rendered) do
      render_inline IconListComponent.new(class: 'custom-class', data: { foo: 'bar' })
    end

    it 'applies tag options to wrapper element' do
      expect(rendered).to have_css('.usa-icon-list.custom-class[data-foo="bar"]')
    end
  end

  context 'with slotted items' do
    subject(:rendered) do
      render_inline IconListComponent.new(icon: :cancel) do |c|
        c.with_item { 'First' }
        c.with_item { 'Second' }
      end
    end

    it 'renders items with default color' do
      expect(rendered).to have_css('.usa-icon-list__icon:not([class*="text-"])', count: 2)
      expect(rendered).to have_xpath('//style[contains(text(), "/cancel-")]')
    end

    context 'with icon or color attributes specified on parent component' do
      subject(:rendered) do
        render_inline IconListComponent.new(icon: :cancel, color: :error) do |c|
          c.with_item { 'First' }
          c.with_item { 'Second' }
        end
      end

      it 'passes those attributes to slotted items' do
        expect(rendered).to have_css('.usa-icon-list__icon.text-error', count: 2)
        expect(rendered).to have_xpath('//style[contains(text(), "/cancel-")]', count: 2)
      end
    end

    context 'with icon and color attributes specified on items' do
      subject(:rendered) do
        render_inline IconListComponent.new do |c|
          c.with_item(icon: :check_circle, color: :success) { 'First' }
          c.with_item(icon: :cancel, color: :error) { 'Second' }
        end
      end

      it 'renders items with their attributes' do
        expect(rendered).to have_css('.usa-icon-list__icon.text-success', count: 1)
        expect(rendered).to have_xpath('//style[contains(text(), "/check_circle-")]', count: 1)
        expect(rendered).to have_css('.usa-icon-list__icon.text-error', count: 1)
        expect(rendered).to have_xpath('//style[contains(text(), "/cancel-")]', count: 1)
      end
    end

    context 'with additional tag options on item' do
      subject(:rendered) do
        render_inline IconListComponent.new(icon: :cancel) do |c|
          c.with_item(class: 'custom-class', data: { foo: 'bar' }) { 'First' }
        end
      end

      it 'applies tag options to wrapper element' do
        expect(rendered).to have_css('.usa-icon-list__item.custom-class[data-foo="bar"]')
      end
    end
  end
end
