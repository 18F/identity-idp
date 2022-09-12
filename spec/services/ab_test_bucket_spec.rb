require 'rails_helper'

describe AbTestBucket do
  let(:foo_percent) { 30 }
  let(:bar_percent) { 20 }
  let(:baz_percent) { 40 }
  let(:default_percent) { 10 }
  let(:acceptable_delta) { 5 }
  let(:subject) do
    AbTestBucket.new(buckets: [{ foo: foo_percent }, { bar: bar_percent }, { baz: baz_percent }])
  end

  context 'configured with buckets adding up to less than 100 percent' do
    it 'splits random uuids into the buckets to within an acceptable delta percent' do
      results = {}
      1000.times do
        bucket = subject.bucket(discriminator: SecureRandom.uuid)
        results[bucket] = (results[bucket] || 0) + 1
      end

      expect(results[:foo].to_f/10).to be_within(acceptable_delta).of(foo_percent)
      expect(results[:bar].to_f/10).to be_within(acceptable_delta).of(bar_percent)
      expect(results[:baz].to_f/10).to be_within(acceptable_delta).of(baz_percent)
      expect(results[:default].to_f/10).to be_within(acceptable_delta).of(default_percent)
    end

    xit 'succeeds a LOT' do
      successes = 0
      failures = 0
      test_runs = 10000
      test_runs.times do
        results = {}
        1000.times do
          bucket = subject.bucket(discriminator: SecureRandom.uuid)
          results[bucket] = (results[bucket] || 0) + 1
        end
        foo_delta = (results[:foo].to_f/10 - foo_percent).abs
        bar_delta = (results[:bar].to_f/10 - bar_percent).abs
        baz_delta = (results[:baz].to_f/10 - baz_percent).abs
        default_delta = (results[:default].to_f/10 - default_percent).abs

        if ((foo_delta < acceptable_delta) &&
          (bar_delta < acceptable_delta) &&
          (baz_delta < acceptable_delta) &&
          (default_delta < acceptable_delta) )
          successes += 1
        else
          failures += 1
        end
      end
      puts "\n\nsuccesses: #{successes}\nfailures: #{failures}\n\n"

      expect(successes).to eq test_runs
    end
  end

  context 'configured with buckets adding up to less exactly 100 percent' do
    let(:baz_percent) { 50 }
    it 'splits random uuids into the buckets to within an acceptable delta percent' do
      results = {}
      1000.times do
        bucket = subject.bucket(discriminator: SecureRandom.uuid)
        results[bucket] = (results[bucket] || 0) + 1
      end

      expect(results[:foo].to_f/10).to be_within(acceptable_delta).of(foo_percent)
      expect(results[:bar].to_f/10).to be_within(acceptable_delta).of(bar_percent)
      expect(results[:baz].to_f/10).to be_within(acceptable_delta).of(baz_percent)
      expect(results[:default]).to be_nil
    end
  end

  context 'configured with no buckets' do
    let(:subject) { AbTestBucket.new }

    it 'returns :default' do
      bucket = subject.bucket(discriminator: SecureRandom.uuid)

      expect(bucket).to eq :default
    end
  end

  context 'configured with buckets adding up to more than 100 percent' do
    let(:foo_percent) { 110 }

    it 'returns :misconfigured' do
      bucket = subject.bucket(discriminator: SecureRandom.uuid)

      expect(bucket).to eq :misconfigured
    end
  end
end
