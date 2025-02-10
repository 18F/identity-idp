require 'spec_helper'
require 'reporting/unknown_progress_bar'

RSpec.describe Reporting::UnknownProgressBar do
  describe '.wrap' do
    let(:output) { StringIO.new }
    let(:show_bar) { true }
    let(:title) { 'my title' }

    subject(:wrap) do
      proc do |&block|
        Reporting::UnknownProgressBar.wrap(show_bar:, title:, output:, &block)
      end
    end

    context 'when show_bar is false' do
      let(:show_bar) { false }

      it 'returns the value inside the block and does not render a bar' do
        result = wrap.call { 10 }

        expect(result).to eq(10)
        expect(output.string).to eq('')
      end
    end

    context 'when show_bar is true' do
      let(:show_bar) { true }

      it 'returns the value inside the block and render a bar with the title' do
        result = wrap.call { 15 }

        expect(result).to eq(15)
        expect(output.string).to include(title)
      end

      it 'kills the background thread that it creates' do
        thread = instance_double('Thread')

        expect(Thread).to receive(:fork).and_return(thread)
        expect(thread).to receive(:kill)

        wrap.call { 11 }
      end
    end
  end
end
