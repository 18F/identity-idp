require 'rails_helper'
load Rails.root.join('bin/query-cloudwatch')

RSpec.describe QueryCloudwatch do
  describe '.parse!' do
    let(:stdin) { build_stdin_without_query }
    let(:argv) { [] }
    let(:stdout) { StringIO.new }
    subject(:parse!) { QueryCloudwatch.parse!(argv:, stdin:, stdout:)}

    before do
      allow(QueryCloudwatch).to receive(:exit)
    end
    context 'with no arguments' do
      
      it 'prints an error messages and exits uncleanly' do
        expect(QueryCloudwatch).to receive(:exit).with(1)
        parse!
        expect(stdout.string).to include "ERROR: missing"
      end
    end

    context 'with --help' do
      let(:argv) { %w[--help] }
      it 'prints help and exits cleanly' do
        expect(QueryCloudwatch).to receive(:exit).with(no_args)
        parse!
        expect(stdout.string).to include "Script to query cloudwatch"
      end
    end

  
    context "with --no-progress" do
      let(:argv) { required_parameters + %w[--no-progress] }

      it "assigns progress to false" do
        config = parse!
        expect(config.progress).to be false
      end
    end

    context "with --progress" do
      let(:argv) { required_parameters + %w[--progress] }

      it "assigns progress to true" do
        config = parse!
        expect(config.progress).to be true
      end
    end
    
    context "with --no-complete" do
      let(:argv) { required_parameters + %w[--no-complete] }

      it "assigns complete to false" do
        config = parse!
        expect(config.complete).to be false
      end
    end

    context "with --complete" do
      let(:argv) { required_parameters + %w[--complete] }

      it "assigns complete to true" do
        config = parse!
        expect(config.complete).to be true
      end
    end
    

    context "with --csv" do
      let(:argv) { required_parameters + %w[--csv] }

      it "assigns format to true" do
        config = parse!
        expect(config.format).to eq :csv
      end
    end

    context "with --json" do
      let(:argv) { required_parameters + %w[--json] }

      it "assigns format to true" do
        config = parse!
        expect(config.format).to eq :json
      end
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

  describe '#run' do
    let(:format) { :csv }
    let(:config) do 
      QueryCloudwatch::Config.new(
        group: "foobar",
        slice: 1.week,
        from: 2.days.ago,
        to: Time.zone.now,
        progress: false,
        wait_duration: 0,
        query: "fields @timestamp, @message",
        format: format,
      )
    end
    let(:query_cloudwatch) { QueryCloudwatch.new(config)}
    let(:stdout) { StringIO.new }
    subject(:run) { query_cloudwatch.run(stdout:) }

    before do
      Aws.config[:cloudwatchlogs] = {
        stub_responses: {
          start_query: [
            { query_id: '123abc' },
          ],
          get_query_results: [
            {
              status: 'Complete',
              results: [
                [
                  { field: '@timestamp', value: 'timestamp-1' },
                  { field: '@message', value: 'message-1' },
                ],
                [
                  { field: '@timestamp', value: 'timestamp-2' },
                  { field: '@message', value: 'message-2' },
                ],
              ],
            },
          ],
        },
      }
    end

    it "outputs a csv format" do
      run
      expect(stdout.string).to eq <<~STR
        timestamp-1,message-1
        timestamp-2,message-2
      STR
    end

    context "with a json format" do
      let(:format) { :json }

      it "outputs newline deliminated json" do
        run
        expect(stdout.string).to eq <<~STR
          {"@timestamp":"timestamp-1","@message":"message-1"}
          {"@timestamp":"timestamp-2","@message":"message-2"}
        STR
      end
    
      
    end
    
  end
end