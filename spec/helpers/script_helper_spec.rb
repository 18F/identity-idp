require 'rails_helper'

RSpec.describe ScriptHelper do
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
        javascript_packs_tag_once('application')
        javascript_packs_tag_once('document-capture', 'document-capture')
        allow(Rails.application.config.asset_sources).to receive(:get_sources).
          with('application').and_return(['/application.js'])
        allow(Rails.application.config.asset_sources).to receive(:get_sources).
          with('document-capture').and_return(['/document-capture.js'])
        allow(Rails.application.config.asset_sources).to receive(:get_assets).with(
          'application',
          'document-capture',
        ).
          and_return(['clock.svg', 'sprite.svg'])
      end

      it 'prints asset paths sources' do
        output = render_javascript_pack_once_tags

        expect(output).to have_css(
          'script[type="application/json"][data-asset-map]',
          visible: :all,
          text: {
            'clock.svg' => 'http://test.host/clock.svg',
            'sprite.svg' => 'http://test.host/sprite.svg',
          }.to_json,
        )
      end

      context 'with configured asset host' do
        let(:production_asset_host) { 'http://assets.example.com' }
        let(:production_domain_name) { 'http://example.com' }

        before do
          allow(IdentityConfig.store).to receive(:asset_host).and_return(production_asset_host)
          allow(IdentityConfig.store).to receive(:domain_name).and_return(production_domain_name)
        end

        it 'uses asset_host for non-same-origin assets and domain_name for same-origin assets' do
          output = render_javascript_pack_once_tags

          expect(output).to have_css(
            'script[type="application/json"][data-asset-map]',
            visible: :all,
            text: {
              'clock.svg' => 'http://assets.example.com/clock.svg',
              'sprite.svg' => 'http://example.com/sprite.svg',
            }.to_json,
          )
        end
      end

      it 'prints script sources' do
        output = render_javascript_pack_once_tags

        expect(output).to have_css(
          "script:not([crossorigin])[src^='/application.js'] ~ \
          script:not([crossorigin])[src^='/document-capture.js']",
          count: 1,
          visible: :all,
        )
      end

      it 'adds preload header without nopush attribute' do
        render_javascript_pack_once_tags

        expect(response.headers['link']).to eq(
          '</application.js>;rel=preload;as=script,' \
            '</document-capture.js>;rel=preload;as=script',
        )
        expect(response.headers['link']).to_not include('nopush')
      end

      context 'with script integrity available' do
        before do
          allow(Rails.application.config.asset_sources).to receive(:get_integrity).and_return(nil)
          allow(Rails.application.config.asset_sources).to receive(:get_integrity).
            with('/application.js').
            and_return('sha256-aztp/wpATyjXXpigZtP8ZP/9mUCHDMaL7OKFRbmnUIazQ9ehNmg4CD5Ljzym/TyA')
        end

        it 'adds integrity attribute' do
          output = render_javascript_pack_once_tags

          expect(output).to have_css(
            "script[src^='/application.js'][integrity^='sha256-']",
            count: 1,
            visible: :all,
          )
        end
      end

      context 'with preload links header disabled' do
        before do
          javascript_packs_tag_once('application', preload_links_header: false)
        end

        it 'does not append preload header' do
          render_javascript_pack_once_tags

          expect(response.headers['link']).to eq('</document-capture.js>;rel=preload;as=script')
        end
      end

      context 'with attributes' do
        before do
          javascript_packs_tag_once('track-errors', defer: true)
          allow(Rails.application.config.asset_sources).to receive(:get_sources).
            with('track-errors').and_return(['/track-errors.js'])
          allow(Rails.application.config.asset_sources).to receive(:get_assets).
            with('application', 'document-capture', 'track-errors').
            and_return([])
        end

        it 'adds attribute' do
          output = render_javascript_pack_once_tags

          expect(output).to have_css(
            "script[src^='/track-errors.js'][defer]",
            count: 1,
            visible: :all,
          )
        end
      end

      context 'with url parameters' do
        before do
          javascript_packs_tag_once(
            'digital-analytics-program',
            url_params: { agency: 'gsa' },
            async: true,
          )
          allow(Rails.application.config.asset_sources).to receive(:get_sources).
            with('digital-analytics-program').and_return(['/digital-analytics-program.js'])
          allow(Rails.application.config.asset_sources).to receive(:get_assets).
            with('application', 'document-capture', 'digital-analytics-program').
            and_return([])
        end

        it 'includes url parameters in script url for the pack' do
          output = render_javascript_pack_once_tags

          expect(output).to have_css(
            "script[src^='/digital-analytics-program.js?agency=gsa'][async]:not([url_params])",
            count: 1,
            visible: :all,
          )

          # URL parameters should not be added to other scripts
          expect(output).to have_css(
            "script[src^='/application.js']",
            count: 1,
            visible: :all,
          )
        end
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
            "script[crossorigin][src^='/application.js'] ~ \
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
        allow(Rails.application.config.asset_sources).to receive(:get_sources).with('application').
          and_return(['/application.js'])
      end

      it 'enqueues those scripts before printing them' do
        output = render_javascript_pack_once_tags('application')

        expect(output).to have_css(
          "script[src='/application.js']",
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
