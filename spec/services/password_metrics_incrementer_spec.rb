require 'rails_helper'

describe PasswordMetricsIncrementer do
  let(:password) { 'saltypickles' }
  let(:guesses_log10) { 7.1 }

  subject { described_class.new(password) }

  describe '#increment_password_metrics' do
    it 'increments password metrics for the length and guesses' do
      subject.increment_password_metrics

      expect(PasswordMetric.where(metric: 'length', value: 12, count: 1).count).to eq(1)
      expect(PasswordMetric.where(metric: 'guesses_log10', value: 7.1, count: 1).count).to eq(1)
    end
  end
end
