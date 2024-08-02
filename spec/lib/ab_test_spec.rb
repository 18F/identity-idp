require 'rails_helper'

RSpec.describe AbTest do
  subject do
    AbTest.new(
      experiment_name: 'test',
      buckets:,
      &discriminator
    )
  end

  let(:discriminator) do
    ->(**) { SecureRandom.uuid }
  end

  let(:buckets) do
    { foo: 20, bar: 30, baz: 50 }
  end

  let(:request) {}

  let(:service_provider) {}

  let(:user) { build(:user) }

  let(:session) { {} }

  let(:user_session) { {} }

  let(:bucket) do
    subject.bucket(
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
        b = subject.bucket(
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
        expect(discriminator).to receive(:call).
          once.
          with(
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
          expect(subject).to receive(:percent).with('some-random-uuid').once.and_call_original
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
        expect { subject }.to raise_error(RuntimeError, 'invalid bucket data structure')
      end
    end

    context 'configured with buckets adding up to more than 100 percent' do
      let(:buckets) { { foo: 60, bar: 60 } }

      it 'raises a RuntimeError' do
        expect { subject }.to raise_error(RuntimeError, 'bucket percentages exceed 100')
      end
    end

    context 'misconfigured with buckets in the wrong data structure' do
      let(:buckets) { [[:foo, 10], [:bar, 20]] }

      it 'raises a RuntimeError' do
        expect { subject }.to raise_error(RuntimeError, 'invalid bucket data structure')
      end
    end
  end
end
