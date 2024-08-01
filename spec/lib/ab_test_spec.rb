require 'rails_helper'

RSpec.describe AbTest do
  subject do
    AbTest.new(
      experiment_name: 'test',
      buckets:,
    )
  end

  let(:buckets) do
    {}
  end

  describe '#bucket' do
    context 'configured with buckets adding up to exactly 100 percent' do
      let(:buckets) do
        { foo: 20, bar: 30, baz: 50 }
      end

      it 'divides random uuids into the buckets with no automatic default' do
        results = {}
        1000.times do
          bucket = subject.bucket(SecureRandom.uuid)
          results[bucket] = results[bucket].to_i + 1
        end

        expect(results[:default]).to be_nil
      end
    end

    context 'configured with no buckets' do
      it 'returns :default' do
        bucket = subject.bucket(SecureRandom.uuid)

        expect(bucket).to eq :default
      end
    end

    context 'configured with buckets with string percentages' do
      let(:buckets) { { foo: '100' } }

      it 'converts string percentages to numbers and returns the correct result' do
        bucket = subject.bucket(SecureRandom.uuid)

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
