require 'rails_helper'
require 'base16'

RSpec.describe Base16 do

  context 'with reasonable inputs' do

    context 'given "Hello, World"' do
      let(:input) { 'Hello, world' }

      it 'returns a known value' do
        encoded = described_class.encode16(input)
        # The IRS confirmed this value:
        expect(encoded).to eq '48656C6C6F2C20776F726C64'

        decoded = described_class.decode16(encoded)
        expect(decoded).to eq input
      end

      it 'returns a value with uppercase letters' do
        encoded = described_class.encode16(input)
        expect(encoded).to eq(encoded.upcase)
      end
    end

    context 'given a sequence of zeroes' do
      let(:input) { "\x00" }
      it 'does not truncate them' do
        encoded = described_class.encode16(input)
        expect(encoded).to eq '00'

        decoded = described_class.decode16(encoded)
        expect(decoded).to eq(input)
      end
    end
  end

  context 'with a less reasonable input' do
    context 'given a zany-face emoji' do
      let(:input) { "🤪" }
      it 'returns the same bytes' do
        encoded = described_class.encode16(input)
        decoded = described_class.decode16(encoded).force_encoding('UTF-8')
        expect(decoded).to eq input
      end
    end
  end

end
