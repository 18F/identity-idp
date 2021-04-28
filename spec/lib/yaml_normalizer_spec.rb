require 'spec_helper'
require 'yaml_normalizer'

RSpec.describe YamlNormalizer do
  describe '.run' do
    let(:tempfile) { Tempfile.new }

    before do
      File.open(tempfile.path, 'w') do |f|
        f.puts <<~YAML
          some:
            value1: 'quoted'
            key: >
              quoted
            value2: "quoted"
        YAML
      end
    end

    after { tempfile.unlink }

    it 'normalizes a YAML files in-place' do
      expect(YamlNormalizer).to receive(:warn).with(tempfile.path)

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
    context 'unsorted keys' do
      let(:original) do
        {
          a: 'a',
          c: 'c',
          d: {
            f: 'f',
            e: 'e',
          },
        }
      end

      let(:sorted) do
        {
          a: 'a',
          c: 'c',
          d: {
            e: 'e',
            f: 'f',
          },
        }
      end

      it 'sorts keys' do
        YamlNormalizer.handle_hash(original)

        expect(original.to_json).to eq(sorted.to_json)
      end
    end

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

    context 'unformatted punctuation' do
      let(:original) { { a: '<strong class="example">Hello "world"...</strong>' } }
      let(:formatted) { { a: '<strong class="example">Hello “world”…</strong>' } }

      it 'formats punctuation' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(formatted)
      end
    end

    context 'booleans' do
      let(:original) { { a: true, b: false } }
      let(:expected) { { a: true, b: false } }

      it 'trims leading newlines but not intermediate ones' do
        YamlNormalizer.handle_hash(original)

        expect(original).to eq(expected)
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
