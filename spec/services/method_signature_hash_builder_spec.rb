require 'rails_helper'

describe MethodSignatureHashBuilder do
  def example_method(
    positional,
    positional_optional = nil,
    keyword:,
    keyword_optional: nil,
    **keyword_splat,
    &block
  ); end

  let(:method_defn) { method(:example_method) }

  describe '.from_hash' do
    it 'extracts keyword arguments from the given hash' do
      result = described_class.from_hash(
        { keyword: 'keyword', keyword_optional: 'keyword_optional' },
        method_defn,
      )

      expect(result).to eq(keyword: 'keyword', keyword_optional: 'keyword_optional')
    end

    it 'is indifferent to key format' do
      result = described_class.from_hash(
        { 'keyword' => 'keyword', keyword_optional: 'keyword_optional' },
        method_defn,
      )

      expect(result).to eq(keyword: 'keyword', keyword_optional: 'keyword_optional')
    end

    it 'defaults missing values to nil' do
      result = described_class.from_hash(
        { keyword_optional: 'keyword_optional' },
        method_defn,
      )

      expect(result).to eq(keyword: nil, keyword_optional: 'keyword_optional')
    end
  end
end
