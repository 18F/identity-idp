require 'rails_helper'

RSpec.describe Agreements::Iaa do
  it 'has a gtc attribute that can be set' do
    iaa = described_class.new(gtc: 'gtc')
    expect(iaa.gtc).to eq('gtc')
  end
  it 'has an order attribute that can be set' do
    iaa = described_class.new(order: 'order')
    expect(iaa.order).to eq('order')
  end
end
