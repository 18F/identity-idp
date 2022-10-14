require 'rails_helper'

RSpec.describe DownloadButtonComponent, type: :component do
  let(:file_data) { 'Downloaded Text' }
  let(:file_name) { 'file.txt' }
  let(:tag_options) { {} }

  subject(:rendered) do
    render_inline DownloadButtonComponent.new(
      file_data: file_data,
      file_name: file_name,
      **tag_options,
    )
  end

  it 'renders link with data and file name' do
    expect(rendered).to have_css(
      "lg-download-button a[href*='#{CGI.escape(file_data)}'][download='#{file_name}']",
    )
  end

  context 'with tag options' do
    let(:tag_options) { { outline: true, data: { foo: 'bar' } } }

    it 'renders button given the tag options' do
      expect(rendered).to have_css('.usa-button.usa-button--outline[data-foo="bar"]')
    end
  end
end
