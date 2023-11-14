require 'spec_helper'
require 'env_irb_prompt'

RSpec.describe EnvIrbPrompt do
  subject(:prompt) { EnvIrbPrompt.new }

  let(:irb_conf) { { PROMPT: {} } }
  let(:on_deployed_box) { false }
  let(:hostname) { '' }

  before do
    allow(File).to receive(:directory?).with('/srv/idp/releases/').and_return(on_deployed_box)
    allow(Socket).to receive(:gethostname).and_return(hostname)
  end

  describe '#configure!' do
    subject(:configure) { prompt.configure!(irb_conf) }

    context 'on a deployed box' do
      let(:on_deployed_box) { true }
      let(:hostname) { 'i-123.dev.example.gov' }

      it 'sets save history to nil' do
        configure
        expect(irb_conf[:SAVE_HISTORY]).to eq(nil)
      end

      it 'sets autocomplete to false' do
        configure
        expect(irb_conf[:USE_AUTOCOMPLETE]).to eq(false)
      end

      it 'sets the prompt with the environment name' do
        configure
        expect(irb_conf[:PROMPT][:ENV_PROMPT][:PROMPT_I]).
          to include(prompt.bold(prompt.color_green('dev')))
      end
    end

    context 'on a local box' do
      let(:on_deployed_box) { false }

      it 'sets save history to 1000' do
        configure
        expect(irb_conf[:SAVE_HISTORY]).to eq(1000)
      end

      it 'sets autocomplete to false' do
        configure
        expect(irb_conf[:USE_AUTOCOMPLETE]).to eq(false)
      end

      it 'sets the prompt with local' do
        configure
        expect(irb_conf[:PROMPT][:ENV_PROMPT][:PROMPT_I]).
          to include(prompt.bold(prompt.color_blue('local')))
      end
    end
  end
end
