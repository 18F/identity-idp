require 'rails_helper'

RSpec.describe BarcodeComponent, type: :component do
  it 'renders expected content' do
    rendered = render_inline BarcodeComponent.new(barcode_data: '1234', label: 'Code')

    caption = page.find_css('img + div', text: 'Code: 1234').first

    expect(rendered).to have_css("img[alt='#{t('components.barcode.image_alt')}']")
    expect(rendered).to have_css("[role=figure][aria-labelledby=#{caption.attr(:id)}]")
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline(
        BarcodeComponent.new(
          barcode_data: '1234',
          label: '',
          data: { foo: 'bar' },
          aria: { hidden: 'false' },
          class: 'example',
        ),
      )

      expect(rendered).to have_css(
        '.example[role=figure][aria-labelledby][data-foo=bar][aria-hidden=false]',
      )
    end
  end

  context 'with empty label' do
    it 'renders label without prefix' do
      rendered = render_inline BarcodeComponent.new(barcode_data: '1234', label: '')

      expect(rendered).to have_css('img + div', text: '1234')
    end
  end

  context 'with label formatter' do
    it 'renders formatted label' do
      rendered = render_inline BarcodeComponent.new(
        barcode_data: '1234',
        label: '',
        label_formatter: ->(barcode_data) { barcode_data + '5678' },
      )

      expect(rendered).to have_css('img + div', text: '12345678')
    end
  end

  context 'with image url method option' do
    it 'renders formatted label' do
      url = 'data:,ok'
      rendered = render_inline BarcodeComponent.new(
        barcode_data: '1234',
        label: '',
        barcode_image_url: url,
      )

      expect(rendered).to have_css("img[src='#{url}']")
    end
  end
end
