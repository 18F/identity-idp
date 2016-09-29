require 'rails_helper'

describe Pii::Attributes do
  describe '#new_from_hash' do
    it 'initializes from plain Hash' do
      pii = described_class.new_from_hash(first_name: 'Jane')

      expect(pii.first_name).to eq 'Jane'
    end
  end
end
