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

  describe '.chomp_each' do
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
        YamlNormalizer.chomp_each(original)

        expect(original).to eq(trimmed)
      end
    end

    context 'trailing spaces' do
      let(:original) { { a: 'a : ', b: 'b ', c: "c : \n" } }
      let(:trimmed) { { a: 'a : ', b: 'b', c: 'c : ' } }

      it 'trims trailing spaces, except after a colon' do
        YamlNormalizer.chomp_each(original)

        expect(original).to eq(trimmed)
      end
    end
  end
end
