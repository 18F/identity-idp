require 'rails_helper'

RSpec.describe ScriptHelper do
  include ScriptHelper

  describe '#javascript_pack_tag_once' do
    it 'returns nil' do
      output = javascript_pack_tag_once('application')

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
        javascript_pack_tag_once('application')
        javascript_pack_tag_once('application')
        javascript_pack_tag_once('clipboard')
      end

      it 'prints all unique packs' do
        output = render_javascript_pack_once_tags

        expect(output).to have_css('script', count: 2, visible: false)
        expect(output).to have_css('script[src^="/packs-test/js/application-"]', visible: false)
        expect(output).to have_css('script[src^="/packs-test/js/clipboard-"]', visible: false)
      end
    end
  end
end
