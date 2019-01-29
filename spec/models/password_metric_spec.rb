require 'rails_helper'

describe PasswordMetric do
  describe '.increment' do
    context 'when a metric with the given metric and value does not exists' do
      it 'creates the metric with a count of 1' do
        PasswordMetric.increment(:length, 10)

        expect(PasswordMetric.count).to eq(1)
        expect(PasswordMetric.find_by(metric: :length, value: 10).count).to eq(1)
      end
    end

    context 'when a metric with the same value exists' do
      before do
        PasswordMetric.create(
          metric: 'length',
          value: 9.0,
          count: 2,
        )
      end

      it 'creates the metric with a value of 1' do
        PasswordMetric.increment(:length, 10)

        expect(PasswordMetric.count).to eq(2)
        expect(PasswordMetric.find_by(metric: :length, value: 10).count).to eq(1)
      end
    end

    context 'when a metric with the given category and value does exist' do
      before do
        PasswordMetric.create(
          metric: 'length',
          value: 10.0,
          count: 1,
        )
      end

      it 'increments the value' do
        PasswordMetric.increment(:length, 10)

        expect(PasswordMetric.count).to eq(1)
        expect(PasswordMetric.find_by(metric: :length, value: 10).count).to eq(2)
      end
    end
  end
end
