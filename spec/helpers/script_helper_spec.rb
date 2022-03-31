require 'rails_helper'

RSpec.describe ScriptHelper do
  include ScriptHelper

  describe '#javascript_include_tag_without_preload' do
    it 'avoids modifying headers' do
      output = javascript_include_tag_without_preload 'application'

      expect(response.header['Link']).to be_nil
      expect(output).to have_css('script', visible: :all)
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
        allow(AssetSources).to receive(:get_sources).with('polyfill').and_return(['/polyfill.js'])
        allow(AssetSources).to receive(:get_sources).with('application', 'document-capture').
          and_return(['/application.js', '/document-capture.js'])
      end

      it 'prints script sources' do
        output = render_javascript_pack_once_tags

        expect(output).to have_css(
          "script:not([crossorigin])[src^='/polyfill.js'][nomodule] ~ \
          script:not([crossorigin])[src^='/application.js'] ~ \
          script:not([crossorigin])[src^='/document-capture.js']",
          count: 1,
          visible: :all,
        )
      end

      context 'local development crossorigin sources' do
        let(:webpack_port) { '3035' }

        before do
          allow(Rails.env).to receive(:development?).and_return(true)
          stub_const('ENV', 'WEBPACK_PORT' => webpack_port)
        end

        it 'prints script sources with crossorigin attribute' do
          output = render_javascript_pack_once_tags

          expect(output).to have_css(
            "script[crossorigin][src^='/polyfill.js'][nomodule] ~ \
            script[crossorigin][src^='/application.js'] ~ \
            script[crossorigin][src^='/document-capture.js']",
            count: 1,
            visible: :all,
          )
        end

        context 'empty webpack port' do
          let(:webpack_port) { '' }

          it 'renders as if webpack port was unassigned' do
            output = render_javascript_pack_once_tags

            expect(output).to_not have_css('[crossorigin]', visible: :all)
          end
        end
      end
    end

    context 'with named scripts argument' do
      before do
        allow(AssetSources).to receive(:get_sources).with('polyfill').and_return(['/polyfill.js'])
        allow(AssetSources).to receive(:get_sources).with('application').
          and_return(['/application.js'])
      end

      it 'enqueues those scripts before printing them' do
        output = render_javascript_pack_once_tags('application')

        expect(output).to have_css(
          "script[src^='/polyfill.js'][nomodule] ~ script[src='/application.js']",
          visible: :all,
        )
      end
    end

    context 'script that does not exist' do
      before do
        javascript_packs_tag_once('nope')
      end

      it 'gracefully outputs nothing' do
        expect(render_javascript_pack_once_tags).to be_nil
      end
    end
  end
end
