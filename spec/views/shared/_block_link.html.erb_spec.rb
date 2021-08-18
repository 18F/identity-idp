require 'rails_helper'

describe 'shared/_block_link.html.erb' do
  let(:url) { '' }
  let(:text) { 'link text' }
  let(:assigns) { { url: url } }

  context 'without block' do
    it 'raises an error' do
      expect do
        render('shared/block_link', url: '/example')
      end.to raise_error('no block content given')
    end
  end

  context 'with block' do
    subject(:rendered) { render('shared/block_link', **assigns) { text } }

    context 'invalid url' do
      let(:url) { '# ' }

      it 'raises an error' do
        expect { rendered }.to raise_error
      end
    end

    context 'relative url' do
      let(:url) { '/example' }

      it 'renders a link' do
        expect(rendered).to have_selector("a[href='#{url}']:not([target])")
        expect(rendered).to have_content(text)
        expect(rendered).not_to have_content(t('links.new_window'))
      end

      context 'forced external' do
        let(:assigns) { { url: url, external: true } }

        it 'renders a link' do
          expect(rendered).to have_selector("a[href='#{url}'][target]")
          expect(rendered).to have_content(text)
          expect(rendered).to have_content(t('links.new_window'))
        end
      end
    end

    context 'same host url' do
      let(:url) { "#{@request.scheme}://#{@request.host_with_port}/example" }

      it 'renders a link' do
        expect(rendered).to have_selector("a[href='#{url}']:not([target])")
        expect(rendered).to have_content(text)
        expect(rendered).not_to have_content(t('links.new_window'))
      end

      context 'forced external' do
        let(:assigns) { { url: url, external: true } }

        it 'renders a link' do
          expect(rendered).to have_selector("a[href='#{url}'][target]")
          expect(rendered).to have_content(text)
          expect(rendered).to have_content(t('links.new_window'))
        end
      end
    end

    context 'external url' do
      let(:url) { 'http://example.com/external' }

      it 'renders a link' do
        expect(rendered).to have_selector("a[href='#{url}'][target]")
        expect(rendered).to have_content(text)
        expect(rendered).to have_content(t('links.new_window'))
      end

      context 'forced non-external' do
        let(:assigns) { { url: url, external: false } }

        it 'renders a link' do
          expect(rendered).to have_selector("a[href='#{url}']:not([target])")
          expect(rendered).to have_content(text)
          expect(rendered).not_to have_content(t('links.new_window'))
        end
      end
    end
  end
end
