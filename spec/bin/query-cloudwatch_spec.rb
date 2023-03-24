require 'rails_helper'
load Rails.root.join('bin/query-cloudwatch')

RSpec.describe QueryCloudwatch do
  describe '.parse!' do
    let(:stdin) { build_stdin_without_query }
    let(:argv) { [] }

    context 'with no arguments' do
      it 'prints an error messages and exits uncleanly' do
      end
    end

    context 'with --help' do
      it 'prints help and exits cleanly' do
      end
    end
  end

  describe '#run' do
  end

  def build_stdin_without_query
    StringIO.new.tap do |io|
      allow(io).to receive(:tty?).and_return(true)
    end
  end

  def build_stdin_with_query(query)
    StringIO.new(query)
  end
end
