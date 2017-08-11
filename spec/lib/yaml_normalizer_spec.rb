require 'spec_helper'
require 'yaml_normalizer'

RSpec.describe YamlNormalizer do
  describe '.run' do
    let(:tempfile) { Tempfile.new }

    before do
      File.open(tempfile.path, 'w') do |f|
        f.puts <<~YAML
          some:
            key: >
              quoted
            value1: 'quoted'
            value2: "quoted"
        YAML
      end
    end

    after { tempfile.unlink }

    it 'normalizes a YAML files in-place' do
      YamlNormalizer.run([tempfile.path])

      expect(File.read(tempfile.path)).to eq <<~YAML
        ---
        some:
          key: quoted
          value1: quoted
          value2: quoted
      YAML
    end
  end

  describe '.handle_hash' do
    context 'trailing newlines' do
      let(:original) do
        {
          key: 'a: ',
          array: %W[b\n c\n],
          nested: {
            value: "d\n",
          },
        }
      end

      let(:trimmed) do
        {
          key: 'a: ',
          array: %w[b c],
          nested: { value: 'd' },
        }
      end

      it 'in-place, recursively trims trailing newlines from all strings in a hash' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(trimmed)
      end
    end

    context 'trailing spaces' do
      let(:original) { { a: 'a : ', b: 'b ', c: "c : \n" } }
      let(:trimmed) { { a: 'a : ', b: 'b', c: 'c : ' } }

      it 'trims trailing spaces, except after a colon' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(trimmed)
      end
    end

    context 'leading newlines' do
      let(:original) { { a: "\n\na b c", b: "a\nb" } }
      let(:trimmed) { { a: 'a b c', b: "a\nb" } }

      it 'trims leading newlines but not intermediate ones' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(trimmed)
      end
    end

    context 'a nil value' do
      let(:original) { { a: nil } }
      let(:trimmed) { { a: nil } }

      it 'does not blow up' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(trimmed)
      end
    end

    context 'array of hashes' do
      let(:original) { { a: [{ b: 'b ' }] } }
      let(:trimmed) { { a: [{ b: 'b' }] } }

      it 'does not blow up' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(trimmed)
      end
    end

    context 'unknown object' do
      let(:original) { { a: Object.new } }

      it 'raises' do
        expect { YamlNormalizer.handle_hash(original) }.to raise_error(ArgumentError)
      end
    end
  end
end
