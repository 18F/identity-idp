require 'rails_helper'

RSpec.describe ScriptHelper do
  include ScriptHelper

  before do
    allow_any_instance_of(ScriptHelper).to receive(:manifest).and_return(
      'entrypoints' => {
        'application' => {
          'assets' => { 'js' => ['/packs/application.js', '/packs/application.en.js'] },
        },
        'document-capture' => {
          'assets' => { 'js' => ['/packs/document-capture.js', '/packs/document-capture.en.js'] },
        },
      },
    )
  end

  describe '#javascript_include_tag_without_preload' do
    it 'avoids modifying headers' do
      javascript_include_tag_without_preload 'application'

      expect(response.header['Link']).to be_nil
    end
  end

  describe '#javascript_packs_tag_once' do
    it 'returns nil' do
      output = javascript_packs_tag_once('application')

      expect(output).to be_nil
    end
  end

  describe '#render_javascript_pack_once_tags' do
    context 'no scripts enqueued' do
      it 'is nil' do
        expect(render_javascript_pack_once_tags).to be_nil
      end
    end

    context 'scripts enqueued' do
      before do
        javascript_packs_tag_once('document-capture', 'document-capture')
        javascript_packs_tag_once('application', prepend: true)
      end

      it 'prints all unique packs in order, locale scripts first' do
        output = render_javascript_pack_once_tags

        selectors = [
          "script[src^='/packs/application.en.js']",
          "script[src^='/packs/document-capture.en.js']",
          "script[src^='/packs/application.js']",
          "script[src^='/packs/document-capture.js']",
        ]

        selectors.each_with_index do |selector, i|
          next_selector = selectors[i + 1]
          test_selector = selector
          test_selector += " ~ #{next_selector}" if next_selector
          expect(output).to have_css(test_selector, count: 1, visible: false)
        end
      end
    end

    context 'script that does not exist' do
      before do
        javascript_packs_tag_once('nope')
      end

      it 'gracefully outputs nothing' do
        expect(render_javascript_pack_once_tags).to be_empty
      end
    end
  end
end
