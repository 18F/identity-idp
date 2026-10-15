require 'rails_helper'

RSpec.describe WaitPeriodFormatter do
  describe '.call' do
    it 'formats short waits in hours' do
      expect(described_class.call(1.day)).to eq('24 hours')
    end

    it 'keeps exactly three days in hours' do
      expect(described_class.call(3.days)).to eq('72 hours')
    end

    it 'formats waits longer than three days in days' do
      expect(described_class.call(4.days)).to eq('4 days')
    end

    it 'uses the current locale' do
      I18n.with_locale(:es) do
        expect(described_class.call(1.day)).to eq('24 horas')
      end
    end
  end
end
