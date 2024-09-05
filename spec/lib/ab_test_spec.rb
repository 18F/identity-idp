require 'rails_helper'

RSpec.describe AbTest do
  subject(:ab_test) do
    AbTest.new(**options, &discriminator)
  end

  let(:options) do
    {
      experiment_name: 'test',
      buckets:,
      should_log:,
    }
  end

  let(:discriminator) do
    ->(**) { SecureRandom.uuid }
  end

  let(:buckets) do
    { foo: 20, bar: 30, baz: 50 }
  end

  let(:should_log) do
    nil
  end

  let(:request) {}

  let(:service_provider) {}

  let(:user) { build(:user) }

  let(:session) { {} }

  let(:user_session) { {} }

  describe '#bucket' do
    subject(:bucket) { ab_test.bucket(**bucket_options) }
    let(:bucket_options) { { request:, service_provider:, session:, user:, user_session: } }

    it 'divides random uuids into the buckets with no automatic default' do
      results = {}
      1000.times do
        b = ab_test.bucket(
          request:,
          service_provider:,
          session:,
          user:,
          user_session:,
        )
        results[b] = results[b].to_i + 1
      end

      expect(results[:default]).to be_nil
    end

    describe 'discriminator invocation' do
      let(:discriminator) do
        ->(request:, service_provider:, user:, user_session:) {
        }
      end
      it 'passes arguments to discriminator' do
        expect(discriminator).to receive(:call)
          .once
          .with(
            request:,
            service_provider:,
            session:,
            user:,
            user_session:,
          )

        bucket
      end
    end

    context 'when no discriminator block provided' do
      let(:discriminator) { nil }
      context 'and user is known' do
        let(:user) do
          build(:user, uuid: 'some-random-uuid')
        end
        it 'uses uuid as discriminator' do
          expect(ab_test).to receive(:percent).with('some-random-uuid').once.and_call_original
          expect(bucket).to eql(:foo)
        end
      end
      context 'and user is not known' do
        let(:user) { nil }
        it 'returns nil' do
          expect(bucket).to be_nil
        end
      end
      context 'and user is anonymous' do
        let(:user) { AnonymousUser.new }
        it 'does not assign a bucket' do
          expect(bucket).to be_nil
        end
      end
    end

    context 'when discriminator returns nil' do
      let(:discriminator) do
        ->(**) {}
      end

      it 'returns nil for bucket' do
        expect(bucket).to be_nil
      end
    end

    context 'configured with no buckets' do
      let(:buckets) { {} }

      it 'returns nil' do
        expect(bucket).to be_nil
      end
    end

    context 'configured with buckets that are all 0' do
      let(:buckets) { { foo: 0, bar: 0 } }
      it 'returns nil for bucket' do
        expect(bucket).to be_nil
      end
    end

    context 'configured with buckets with string percentages' do
      let(:buckets) { { foo: '100' } }

      it 'converts string percentages to numbers and returns the correct result' do
        expect(bucket).to eq :foo
      end
    end

    context 'configured with buckets with random strings' do
      let(:buckets) { { foo: 'foo', bar: 'bar' } }

      it 'raises a RuntimeError' do
        expect { ab_test }.to raise_error(RuntimeError, 'invalid bucket data structure')
      end
    end

    context 'configured with buckets adding up to more than 100 percent' do
      let(:buckets) { { foo: 60, bar: 60 } }

      it 'raises a RuntimeError' do
        expect { ab_test }.to raise_error(RuntimeError, 'bucket percentages exceed 100')
      end
    end

    context 'misconfigured with buckets in the wrong data structure' do
      let(:buckets) { [[:foo, 10], [:bar, 20]] }

      it 'raises a RuntimeError' do
        expect { ab_test }.to raise_error(RuntimeError, 'invalid bucket data structure')
      end
    end

    context 'with persisted ab test' do
      let(:user) { create(:user) }
      let(:discriminator) { nil }
      let(:options) { super().merge(persist: true) }

      context 'without existing assignment' do
        it 'creates and returns new assignment' do
          expect { bucket }.to change { AbTestAssignment.count }.by(1)
          expect(bucket).to be_kind_of(Symbol)
        end

        context 'with persisted_read_only option' do
          let(:bucket_options) { super().merge(persisted_read_only: true) }

          it { is_expected.to be_nil }

          it 'does not create a new assignment' do
            expect { bucket }.not_to change { AbTestAssignment.count }
          end
        end
      end

      context 'with existing assignment' do
        before do
          create(
            :ab_test_assignment,
            experiment: ab_test.experiment,
            discriminator: user.uuid,
            bucket: 'foo',
          )
        end

        it 'returns existing assignment without creating new' do
          expect { bucket }.not_to change { AbTestAssignment.count }
          expect(bucket).to eq(:foo)
        end
      end
    end
  end

  describe '#include_in_analytics_event?' do
    let(:event_name) { 'My cool event' }

    subject(:return_value) { ab_test.include_in_analytics_event?(event_name) }

    context 'when should_log is nil' do
      it { is_expected.to eql(false) }
    end

    context 'when Regexp is used' do
      context 'and it matches' do
        let(:should_log) { /cool/ }

        it { is_expected.to eql(true) }
      end

      context 'and it does not match' do
        let(:should_log) { /not cool/ }

        it { is_expected.to eql(false) }
      end
    end

    context 'when object responding to `include?` is used' do
      context 'and it matches' do
        let(:should_log) do
          Class.new do
            def include?(event_name)
              event_name == 'My cool event'
            end
          end.new
        end

        it { is_expected.to eq(true) }
      end

      context 'and it does not match' do
        let(:should_log) do
          Class.new do
            def include?(event_name)
              event_name == 'My not cool event'
            end
          end.new
        end

        it { is_expected.to eq(false) }
      end
    end

    context 'when true is used' do
      let(:should_log) { true }
      it 'raises' do
        expect { return_value }.to raise_error
      end
    end

    context 'when false is used' do
      let(:should_log) { false }
      it 'raises' do
        expect { return_value }.to raise_error
      end
    end
  end

  describe '#report' do
    subject(:report) { ab_test.report }
    let(:options) { super().merge(report: report_option) }
    let(:report_option) do
      { email: 'email@example.com', queries: [{ title: 'Example Query', query: 'limit 1' }] }
    end

    it 'builds struct value from given hash option' do
      expect(report).to be_a(AbTest::ReportConfig)
      expect(report.experiment_name).to eq('test')
      expect(report.email).to eq('email@example.com')
      expect(report.queries).to all be_a(AbTest::ReportQueryConfig)
      expect(report.queries.first.title).to eq('Example Query')
      expect(report.queries.first.query).to eq('limit 1')
    end

    context 'with nil report option' do
      let(:report_option) { nil }

      it { is_expected.to be_nil }
    end

    context 'with blank options' do
      let(:report_option) { {} }

      it 'gracefully builds an empty struct value' do
        expect(report).to be_a(AbTest::ReportConfig)
        expect(report.experiment_name).to eq('test')
        expect(report.email).to be_nil
        expect(report.queries).to eq([])
      end
    end
  end

  describe '#active?' do
    subject(:active) { ab_test.active? }

    context 'with non-zero buckets' do
      let(:buckets) { { foo: 0, bar: 30, baz: 0 } }

      it { is_expected.to be true }
    end

    context 'with all zero buckets' do
      let(:buckets) { { foo: 0, bar: 0, baz: 0 } }

      it { is_expected.to be false }
    end

    context 'with empty buckets' do
      let(:buckets) { {} }

      it { is_expected.to be false }
    end
  end
end
