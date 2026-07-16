require 'rails_helper'

RSpec.describe DownloadButtonComponent, type: :component do
  let(:file_data) { 'Downloaded Text' }
  let(:file_name) { 'file.txt' }
  let(:tag_options) { {} }
  let(:instance) do
    DownloadButtonComponent.new(
      file_data:,
      file_name:,
      **tag_options,
    )
  end

  subject(:rendered) { render_inline instance }

  it 'renders link with data and file name' do
    expect(rendered).to have_css(
      "a[href='data:text/plain;charset=utf-8,Downloaded%20Text'][download='#{file_name}']",
      text: t('components.download_button.label'),
    )
  end

  context 'with tag options' do
    let(:tag_options) { { variant: :quaternary, size: :sm, data: { foo: 'bar' } } }

    it 'passes options through to the button' do
      expect(rendered).to have_css('a[data-foo="bar"]')
    end
  end

  context 'with content' do
    let(:content) { 'Download File' }
    let(:instance) { super().with_content(content) }

    it 'renders with the given content' do
      expect(rendered).to have_content(content)
    end
  end
end
