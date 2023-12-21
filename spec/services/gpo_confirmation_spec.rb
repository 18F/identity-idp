require 'rails_helper'

RSpec.describe GpoConfirmation do
  let(:valid_attributes) do
    {
      address1: '1234 Imaginary Ave',
      address2: '',
      city: 'Anywhere',
      otp: 'ABCD1234',
      first_name: 'Pat',
      last_name: 'Person',
      state: 'OH',
      zipcode: '56789',
      issuer: nil,
    }
  end

  let(:attributes) { valid_attributes }

  let(:encryptor) { Encryption::Encryptors::BackgroundProofingArgEncryptor.new }

  subject { GpoConfirmation.create!(entry: attributes) }

  describe '#entry' do
    it 'stores the entry as an encrypted json string' do
      # Since the encryption is different every time, we'll just make sure this
      # is some non-empty string thats NOT the json version of the attributes.
      expect(subject[:entry]).to be_a(String)
      expect(subject[:entry]).not_to be_empty
      expect(subject[:entry]).not_to eq(attributes.to_json)
      expect(parse(subject[:entry])).to eq(attributes)
    end

    it 'retrieves the entry as an unencrypted hash with symbolized keys' do
      expect(subject.entry).to eq(attributes)
    end

    describe 'validation' do
      it 'passes when valid' do
        expect { subject }.not_to raise_error
      end

      %i[otp address1 city state zipcode].each do |prop|
        context "#{prop} not present" do
          let(:attributes) { valid_attributes.tap { |a| a.delete(prop) } }
          it 'fails validation' do
            expect { subject }.to raise_error
          end
        end

        context "#{prop} all whitespace" do
          let(:attributes) { valid_attributes.tap { |a| a[prop] = "\n\t\t " } }
          it 'fails validation' do
            expect { subject }.to raise_error
          end
        end
      end

      [
        ['0184', false],
        ['982251', false],
        [' 98225 ', true],
        [' 98225 - 3938 ', true],
        [' 98225 - 393 ', false],
        ['98225-3938', true],
        ['982253938', true],
        ['1234', false],
      ].each do |input, should_pass|
        context "zipcode = #{input.inspect}" do
          let(:attributes) { valid_attributes.tap { |a| a[:zipcode] = input } }
          if should_pass
            it 'validates' do
              expect { subject }.not_to raise_error
            end
          else
            it 'does not validate' do
              expect { subject }.to raise_error
            end
          end
        end
      end
    end
  end

  def parse(json)
    JSON.parse(encryptor.decrypt(json), symbolize_names: true)
  end
end
