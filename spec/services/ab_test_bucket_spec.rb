require 'rails_helper'

describe AbTestBucket do
  let(:foo_percent) { 30 }
  let(:bar_percent) { 20 }
  let(:baz_percent) { 40 }
  let(:default_percent) { 10 }
  let(:subject) do
    AbTestBucket.new(buckets: { foo: foo_percent, bar: bar_percent, baz: baz_percent })
  end

  context 'configured with buckets adding up to less than 100 percent' do
    let(:foo_uuid) { SecureRandom.uuid }
    let(:bar_uuid) { SecureRandom.uuid }
    let(:baz_uuid) { SecureRandom.uuid }
    let(:default_uuid) { SecureRandom.uuid }
    before do
      allow_any_instance_of(AbTestBucket).to receive(:percent).with(foo_uuid).and_return(15)
      allow_any_instance_of(AbTestBucket).to receive(:percent).with(bar_uuid).and_return(40)
      allow_any_instance_of(AbTestBucket).to receive(:percent).with(baz_uuid).and_return(60)
      allow_any_instance_of(AbTestBucket).to receive(:percent).with(default_uuid).and_return(95)
    end
    it 'sorts uuids into the buckets' do
      expect(subject.bucket(foo_uuid)).to eq(:foo)
      expect(subject.bucket(bar_uuid)).to eq(:bar)
      expect(subject.bucket(baz_uuid)).to eq(:baz)
      expect(subject.bucket(default_uuid)).to eq(:default)
    end
  end

  context 'with random data over many runs' do
    let(:acceptable_delta) { 5 }

    # A slow test that runs the above 10000 times and reports the number of times it fails to pass
    # due to the random nature of the test. With acceptable_delta == 5, the above spec succeeded
    # 99.78% of the time.
    xit 'succeessfully sorts data to within an acceptable delta of the desired percentage' do
      successes = 0
      failures = 0
      test_runs = 10000
      test_runs.times do
        results = {}
        1000.times do
          bucket = subject.bucket(SecureRandom.uuid)
          results[bucket] = (results[bucket] || 0) + 1
        end
        foo_delta = (results[:foo].to_f / 10 - foo_percent).abs
        bar_delta = (results[:bar].to_f / 10 - bar_percent).abs
        baz_delta = (results[:baz].to_f / 10 - baz_percent).abs
        default_delta = (results[:default].to_f / 10 - default_percent).abs

        if ((foo_delta < acceptable_delta) &&
          (bar_delta < acceptable_delta) &&
          (baz_delta < acceptable_delta) &&
          (default_delta < acceptable_delta))
          successes += 1
        else
          failures += 1
        end
      end
      puts "\n\nsuccesses: #{successes}\nfailures: #{failures}\n\n"

      expect(successes).to eq test_runs
    end
  end

  context 'configured with buckets adding up to exactly 100 percent' do
    let(:subject) do
      AbTestBucket.new(buckets: { foo: 20, bar: 30, baz: 50 })
    end

    it 'divides random uuids into the buckets with no automatic default' do
      results = {}
      1000.times do
        bucket = subject.bucket(SecureRandom.uuid)
        results[bucket] = (results[bucket] || 0) + 1
      end

      expect(results[:default]).to be_nil
    end
  end

  context 'configured with no buckets' do
    let(:subject) { AbTestBucket.new }

    it 'returns :default' do
      bucket = subject.bucket(SecureRandom.uuid)

      expect(bucket).to eq :default
    end
  end

  context 'configured with buckets with string percentages' do
    let(:subject) { AbTestBucket.new(buckets: { foo: '100' }) }

    it 'converts string percentages to numbers and returns the correct result' do
      bucket = subject.bucket(SecureRandom.uuid)

      expect(bucket).to eq :foo
    end
  end

  context 'configured with buckets with random strings' do
    let(:subject) { AbTestBucket.new(buckets: { foo: 'foo', bar: 'bar' }) }

    it 'converts string to zero percent and returns :default' do
      bucket = subject.bucket(SecureRandom.uuid)

      expect(bucket).to eq :default
    end
  end

  context 'configured with buckets adding up to more than 100 percent' do
    let(:foo_percent) { 110 }

    it 'raises a RuntimeError' do
      expect { subject }.to raise_error(RuntimeError, 'bucket percentages exceed 100')
    end
  end

  context 'misconfigured with buckets in the wrong data structure' do
    let(:subject) { AbTestBucket.new(buckets: [[:foo, 10], [:bar, 20]]) }

    it 'raises a RuntimeError' do
      expect { subject }.to raise_error(RuntimeError, 'invalid bucket data structure')
    end
  end
end
