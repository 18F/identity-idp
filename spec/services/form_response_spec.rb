require 'rails_helper'

describe FormResponse do
  describe '.new' do
    it 'raises an error if errors is not a Hash' do
      errors = ['bar', [{ foo: 'bar' }], ['foobar']]

      errors.each do |error|
        expect { FormResponse.new(success: true, errors: error) }.
          to raise_error NoMethodError
      end
    end
  end

  describe '#success?' do
    context 'when the success argument is true' do
      it 'returns true' do
        response = FormResponse.new(success: true, errors: {})

        expect(response.success?).to eq true
      end
    end

    context 'when the success argument is false' do
      it 'returns false' do
        response = FormResponse.new(success: false, errors: {})

        expect(response.success?).to eq false
      end
    end
  end

  describe '#errors' do
    it 'returns the value of the errors argument' do
      errors = { foo: 'bar' }
      response = FormResponse.new(success: true, errors: errors)

      expect(response.errors).to eq errors
    end
  end

  describe '#to_h' do
    context 'when the extra argument is nil' do
      it 'returns a hash with success and errors keys' do
        errors = { foo: 'bar' }
        response = FormResponse.new(success: true, errors: errors)
        response_hash = {
          success: true,
          errors: errors
        }

        expect(response.to_h).to eq response_hash
      end
    end

    context 'when the extra argument is present' do
      it 'returns a hash with success and errors keys, and any keys from the extra hash' do
        errors = { foo: 'bar' }
        extra = { user_id: 1, context: 'confirmation' }
        response = FormResponse.new(success: true, errors: errors, extra: extra)
        response_hash = {
          success: true,
          errors: errors,
          user_id: 1,
          context: 'confirmation'
        }

        expect(response.to_h).to eq response_hash
      end
    end
  end
end
