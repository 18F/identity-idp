require 'rails_helper'

RSpec.describe StylesheetHelper do
  describe '#stylesheet_tag_once' do
    it 'returns nil' do
      output = stylesheet_tag_once('styles')

      expect(output).to be_nil
    end
  end

  describe '#render_stylesheet_once_tags' do
    context 'no stylesheets enqueued' do
      it 'is nil' do
        expect(render_stylesheet_once_tags).to be_nil
      end
    end

    context 'stylesheets enqueued' do
      before do
        stylesheet_tag_once('styles')
      end

      it 'prints stylesheets' do
        output = render_stylesheet_once_tags

        expect(output).to have_css(
          'link[rel="stylesheet"][href="/stylesheets/styles.css"]',
          count: 1,
          visible: :all,
        )
      end

      it 'adds preload header without nopush attribute' do
        render_stylesheet_once_tags

        expect(response.headers['link']).to eq('</stylesheets/styles.css>;rel=preload;as=style')
        expect(response.headers['link']).to_not include('nopush')
      end
    end

    context 'same stylesheet enqueued multiple times' do
      before do
        stylesheet_tag_once('styles')
        stylesheet_tag_once('styles')
      end

      it 'prints stylesheets once' do
        output = render_stylesheet_once_tags

        expect(output).to have_css(
          'link[rel="stylesheet"][href="/stylesheets/styles.css"]',
          count: 1,
          visible: :all,
        )
      end
    end

    context 'multiple stylesheets enqueued' do
      before do
        stylesheet_tag_once('styles-a')
        stylesheet_tag_once('styles-b')
      end

      it 'prints stylesheets once, in order' do
        output = render_stylesheet_once_tags

        expect(output).to have_css(
          'link[rel="stylesheet"][href="/stylesheets/styles-a.css"] ~ ' \
            'link[rel="stylesheet"][href="/stylesheets/styles-b.css"]',
          count: 1,
          visible: :all,
        )
      end
    end

    context 'with named stylesheets argument' do
      before do
        stylesheet_tag_once('styles-a')
      end

      it 'enqueues those stylesheets before printing them' do
        output = render_stylesheet_once_tags('styles-b')

        expect(output).to have_css(
          'link[rel="stylesheet"][href="/stylesheets/styles-a.css"] ~ ' \
            'link[rel="stylesheet"][href="/stylesheets/styles-b.css"]',
          count: 1,
          visible: :all,
        )
      end
    end
  end
end
