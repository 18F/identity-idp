require 'rails_helper'

RSpec.describe ScriptHelper do
  include ScriptHelper

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
        javascript_packs_tag_once('clipboard', 'clipboard')
        javascript_packs_tag_once('document-capture')
        javascript_packs_tag_once('application', prepend: true)
      end

      it 'prints all unique packs in order' do
        output = render_javascript_pack_once_tags

        application_pack_selector = 'script[src^="/packs-test/js/application-"]'
        clipboard_pack_selector = 'script[src^="/packs-test/js/clipboard-"]'
        document_capture_pack_selector = 'script[src^="/packs-test/js/document-capture-"]'

        expect(output).to have_css(
          application_pack_selector,
          count: 1,
          visible: false,
        )
        expect(output).to have_css(
          "#{application_pack_selector} ~ #{clipboard_pack_selector}",
          count: 1,
          visible: false,
        )
        expect(output).to have_css(
          "#{clipboard_pack_selector} ~ #{document_capture_pack_selector}",
          count: 1,
          visible: false,
        )
      end
    end
  end
end
