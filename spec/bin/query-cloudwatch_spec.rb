require 'rails_helper'
require 'sqlite3'
load Rails.root.join('bin/query-cloudwatch')

RSpec.describe QueryCloudwatch do
  describe '.parse!' do
    let(:stdin) { build_stdin_without_query }
    let(:argv) { [] }
    let(:stdout) { StringIO.new }
    let(:required_parameters) { %w[--from 1d --group some/log --query fields\ @message] }
    let(:now) { Time.zone.now }
    subject(:parse!) { QueryCloudwatch.parse!(argv:, stdin:, stdout:, now:) }

    before do
      allow(QueryCloudwatch).to receive(:exit)
      allow(Reporting::CloudwatchClient).to receive(:MAX_RESULTS_LIMIT).and_return(10_000)
    end

    context 'with no arguments' do
      it 'prints an error messages and exits uncleanly' do
        expect(QueryCloudwatch).to receive(:exit).with(1)
        parse!
        expect(stdout.string).to include 'ERROR: missing'
      end
    end

    context 'with --help' do
      let(:argv) { %w[--help] }
      it 'prints help and exits cleanly' do
        expect(QueryCloudwatch).to receive(:exit).with(no_args)
        parse!
        expect(stdout.string).to include 'Script to query cloudwatch'
      end
    end

    context 'passing in a query' do
      let(:required_nonquery_args) { %w[--from 1d --group some/log] }
      context 'passing in no query' do
        let(:argv) { required_nonquery_args }
        let(:stdin) { build_stdin_without_query }

        it 'returns an error' do
          parse!
          expect(stdout.string).to include 'ERROR'
        end
      end

      context 'passing in a query in argv' do
        let(:stdin) { build_stdin_without_query }
        let(:argv) { required_parameters }

        it 'assigns query to query' do
          config = parse!
          expect(config.query).to include 'fields @message'
        end
      end

      context 'passing in a query in stdin' do
        let(:stdin) { build_stdin_with_query('fields @message') }
        let(:argv) { required_nonquery_args }

        it 'assigns query to query' do
          config = parse!
          expect(config.query).to include 'fields @message'
        end
      end
    end

    context '--app and --env and --log' do
      let(:required_nongroup_parameters) { %w[--from 1d --query fields\ @message] }
      let(:argv) { required_parameters + %w[--app idp --env int --log events.log] }

      it 'builds a log group' do
        config = parse!
        expect(config.group).to eq('int_/srv/idp/shared/log/events.log')
      end
    end

    context 'with --to' do
      let(:argv) { required_parameters + ['--to', to] }

      context 'with a duration' do
        let(:to) { '5w' }

        it 'parses the duration' do
          config = parse!
          expect(config.to).to eq(5.weeks.ago(now))
        end
      end

      context 'with a timestamp' do
        let(:to) { '2023-01-01T00:00:00Z' }

        it 'parses the timestmap' do
          config = parse!
          expect(config.to).to eq(Date.new(2023, 1, 1).in_time_zone('UTC').beginning_of_day)
        end
      end
    end

    context 'with --date' do
      let(:argv) { required_parameters + ['--date', '2023-01-01,2023-08-01'] }

      it 'creates disjoint time slices' do
        config = parse!
        expect(config.time_slices).to eq(
          [
            Date.new(2023, 1, 1).in_time_zone('UTC').all_day,
            Date.new(2023, 8, 1).in_time_zone('UTC').all_day,
          ],
        )
      end
    end

    context 'with --no-progress' do
      let(:argv) { required_parameters + %w[--no-progress] }

      it 'assigns progress to false' do
        config = parse!
        expect(config.progress).to be false
      end
    end

    context 'with --progress' do
      let(:argv) { required_parameters + %w[--progress] }

      it 'assigns progress to true' do
        config = parse!
        expect(config.progress).to be true
      end
    end

    context 'with --no-complete' do
      let(:argv) { required_parameters + %w[--no-complete] }

      it 'assigns complete to false' do
        config = parse!
        expect(config.complete).to be false
      end
    end

    context 'with --complete' do
      let(:argv) { required_parameters + %w[--complete] }

      it 'assigns complete to true' do
        config = parse!
        expect(config.complete).to be true
      end
    end

    context 'with --csv' do
      let(:argv) { required_parameters + %w[--csv] }

      it 'assigns format to true' do
        config = parse!
        expect(config.format).to eq :csv
      end
    end

    context 'with --json' do
      let(:argv) { required_parameters + %w[--json] }

      it 'assigns format to true' do
        config = parse!
        expect(config.format).to eq :json
      end
    end

    context 'with --sqlite' do
      let(:argv) { required_parameters + %w[--sqlite] }

      it 'sets sqlite_database_file to events.db by default' do
        config = parse!
        expect(config.sqlite_database_file).to eql('events.db')
      end

      context 'with a database file' do
        let(:argv) { required_parameters + %w[--sqlite foo.db] }
        it 'sets sqlite_database_file appropriately' do
          config = parse!
          expect(config.sqlite_database_file).to eql('foo.db')
        end
      end

      context 'with --count-distinct' do
        let(:argv) { super() + %w[--count-distinct foo] }
        it 'errors out' do
          expect(QueryCloudwatch).to receive(:exit).with(1)
          parse!
          expect(stdout.string).to include("can't do --count-distinct with --sqlite")
        end
      end
    end

    context 'with --slice' do
      let(:argv) { required_parameters + %w[--slice 3mon] }

      it 'assigns the slice duration' do
        config = parse!
        expect(config.slice).to eq(3.months)
      end
    end

    context 'with --count-distinct' do
      let(:argv) { required_parameters + %w[--count-distinct properties.user_id] }

      it 'assigns the count_distinct field config' do
        config = parse!
        expect(config.count_distinct).to eq('properties.user_id')
      end

      it 'revises the query' do
        config = parse!
        expect(config.query).to eq <<~STR.chomp
          fields @message
          | stats count(*) by properties.user_id
          | limit 10000
        STR
      end

      it 'toggles complete config' do
        config = parse!
        expect(config.complete).to eq(true)
      end
    end

    context 'number of threads' do
      let(:argv) { required_parameters }

      it 'defaults to Reporting::CloudwatchClient::DEFAULT_NUM_THREADS' do
        config = parse!
        expect(config.num_threads).to eq(Reporting::CloudwatchClient::DEFAULT_NUM_THREADS)
      end

      context 'with --num-threads' do
        let(:argv) { required_parameters + %w[--num-threads 15] }

        it 'overrides the number of threads' do
          config = parse!
          expect(config.num_threads).to eq(15)
        end
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
    let(:count_distinct) { nil }
    let(:config) do
      QueryCloudwatch::Config.new(
        group: 'foobar',
        slice: 1.week,
        from: 2.days.ago,
        to: Time.zone.now,
        progress: false,
        wait_duration: 0,
        query: 'fields @timestamp, @message',
        format: format,
        sqlite_database_file: 'events.db',
        count_distinct: count_distinct,
        num_threads: Reporting::CloudwatchClient::DEFAULT_NUM_THREADS,
      )
    end
    let(:query_cloudwatch) { QueryCloudwatch.new(config) }
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:query_results) do
      [
        [
          { field: '@timestamp', value: 'timestamp-1' },
          { field: '@message', value: 'message-1' },
        ],
        [
          { field: '@timestamp', value: 'timestamp-2' },
          { field: '@message', value: 'message-2' },
        ],
      ]
    end

    subject(:run) { query_cloudwatch.run(stdout:, stderr:) }

    before do
      Aws.config[:cloudwatchlogs] = {
        stub_responses: {
          start_query: [
            { query_id: '123abc' },
          ],
          get_query_results: [
            {
              status: 'Complete',
              results: query_results,
            },
          ],
        },
      }
    end

    it 'outputs a csv format' do
      run
      expect(stdout.string).to eq <<~STR
        timestamp-1,message-1
        timestamp-2,message-2
      STR
    end

    context 'with a json format' do
      let(:format) { :json }

      it 'outputs newline deliminated json' do
        run
        expect(stdout.string).to eq <<~STR
          {"@timestamp":"timestamp-1","@message":"message-1"}
          {"@timestamp":"timestamp-2","@message":"message-2"}
        STR
      end
    end

    context 'with sqlite format' do
      let(:format) { :sqlite }

      let(:db) do
        SQLite3::Database.new(':memory:')
      end

      before do
        allow_any_instance_of(QueryCloudwatch::SqliteOutput).to receive(:db)
          .and_return(db)
        allow_any_instance_of(QueryCloudwatch::SqliteOutput).to receive(:close_database)
      end

      it 'does not output on stdout' do
        run
        expect(stdout.string).to eql('')
      end

      context 'with invalid json in @message' do
        let(:message_1) { 'message 1 here, not at all json' }
        let(:message_2) { 'message 2 here, not at all json' }

        let(:query_results) do
          [
            [
              { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
              { field: '@message', value: message_1 },
            ],
            [
              { field: '@timestamp', value: '"2024-01-02 03:42:50.451",' },
              { field: '@message', value: message_2 },
            ],
          ]
        end

        it 'generates ids for events that start with NOID-' do
          run
          expect(db.get_first_value('SELECT COUNT(*) FROM events')).to eql(2)

          actual_ids = db.query('SELECT id FROM events') do |results|
            results.map do |row|
              row.first
            end
          end

          expect(actual_ids).to all(start_with('NOID-'))
        end

        it 'outputs warnings + summary on stderr' do
          run
          expect(stderr.string).to eql <<~STR
            WARNING: For 2 events, @message did not contain valid JSON
            Wrote 2 rows to the 'events' table in events.db
          STR
        end

        context 'two messages are identitical' do
          let(:query_results) do
            [
              [
                { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
                { field: '@message', value: message_1 },
              ],
              [
                { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
                { field: '@message', value: message_1 },
              ],
            ]
          end
          it 'only inserts 1 record' do
            run
            expect(db.get_first_value('SELECT COUNT(*) FROM events')).to eql(1)
          end
        end
      end

      context 'with valid JSON in @message' do
        let(:message_1) do
          JSON.parse(<<~JSON)
            {
              "id": "message_1",
              "name": "IdV: doc auth image upload vendor submitted",
              "properties": {
                "event_properties": {
                  "success": true,
                  "errors": {},
                  "exception": null
                },
                "user_id": "user_1"
              }
            }
          JSON
        end

        let(:message_2) do
          JSON.parse(<<~JSON)
            {
              "id": "message_2",
              "name": "IdV: doc auth image upload vendor submitted",
              "properties": {
                "event_properties": {
                  "success": false,
                  "errors": {},
                  "exception": null
                },
                "user_id": "user_2"
              }
            }
          JSON
        end

        let(:query_results) do
          [
            [
              { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
              { field: '@message', value: JSON.generate(message_1) },
            ],
            [
              { field: '@timestamp', value: '"2024-01-02 03:42:50.451",' },
              { field: '@message', value: JSON.generate(message_2) },
            ],
          ]
        end

        it 'inserts 2 rows in events table' do
          run
          expect(db.get_first_value('SELECT COUNT(*) FROM events')).to eql(2)
        end

        context 'when two messages have same id' do
          let(:message_2) { message_1 }

          it 'only inserts 1 row' do
            run
            expect(db.get_first_value('SELECT COUNT(*) FROM events')).to eql(1)
          end
        end
      end

      context 'when query does not return @timestamp' do
        let(:query_results) do
          [
            [
              { field: '@message', value: '{}' },
            ],
            [
              { field: '@message', value: '{}' },
            ],
          ]
        end

        it 'errors out' do
          expect do
            run
          end.to raise_error 'Query must include @timestamp in output when using --sqlite'
        end
      end

      context 'when query does not return @message' do
        let(:query_results) do
          [
            [
              { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
            ],
            [
              { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
            ],
          ]
        end

        it 'errors out' do
          expect do
            run
          end.to raise_error 'Query must include @message in output when using --sqlite'
        end
      end

      context 'when query returns @log' do
        let(:query_results) do
          [
            [
              { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
              { field: '@message', value: '{}' },
              { field: '@log', value: 'my log' },
            ],
            [
              { field: '@timestamp', value: '"2024-01-02 03:42:50.451",' },
              { field: '@message', value: '{}' },
              { field: '@log', value: 'my other log' },
            ],
          ]
        end

        it 'adds them to the log column' do
          run
          actual_log_values = db.query('SELECT log FROM events') do |results|
            results.map(&:first)
          end.sort

          expect(actual_log_values).to eql(['my log', 'my other log'])
        end
      end

      context 'when query returns @logStream' do
        let(:query_results) do
          [
            [
              { field: '@timestamp', value: '2024-01-11 22:26:50.336' },
              { field: '@message', value: '{}' },
              { field: '@logStream', value: 'my log stream' },
            ],
            [
              { field: '@timestamp', value: '"2024-01-02 03:42:50.451",' },
              { field: '@message', value: '{}' },
              { field: '@logStream', value: 'my other log stream' },
            ],
          ]
        end

        it 'adds them to the log_stream column' do
          run

          actual_log_stream_values = db.query('SELECT log_stream FROM events') do |results|
            results.map(&:first)
          end.sort

          expect(actual_log_stream_values).to eql(['my log stream', 'my other log stream'])
        end
      end
    end

    context 'with count distinct' do
      let(:count_distinct) { '@message' }

      it 'outputs sum count' do
        run
        expect(stdout.string.strip).to eq '2'
      end
    end
  end
end
