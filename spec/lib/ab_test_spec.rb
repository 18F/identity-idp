require 'rails_helper'

RSpec.describe AbTest do
  subject(:ab_test) do
    AbTest.new(
      experiment_name: 'test',
      buckets:,
      should_log:,
      &discriminator
    )
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

  let(:bucket) do
    ab_test.bucket(
      request:,
      service_provider:,
      session:,
      user:,
      user_session:,
    )
  end

  describe '#bucket' do
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
  end

  describe '#include_in_analytics_event?' do
    let(:event_name) { 'My cool event' }

    subject(:return_value) { ab_test.include_in_analytics_event?(event_name) }

    context 'when should_log is nil' do
      it 'returns true' do
        expect(return_value).to eql(true)
      end
    end

    context 'when Regexp is used' do
      context 'and it matches' do
        let(:should_log) { /cool/ }
        it 'returns true' do
          expect(return_value).to eql(true)
        end
      end
      context 'and it does not match' do
        let(:should_log) { /not cool/ }
        it 'returns false' do
          expect(return_value).to eql(false)
        end
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
end
