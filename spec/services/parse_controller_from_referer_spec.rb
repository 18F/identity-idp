require 'rails_helper'

describe ParseControllerFromReferer do
  describe '#call' do
    context 'when the referer is nil' do
      it 'returns "no referer" string' do
        parser = ParseControllerFromReferer.new(nil)

        expect(parser.call).to eq 'no referer'
      end
    end

    context 'when the referer is present' do
      it 'returns the corresponding controller and action' do
        parser = ParseControllerFromReferer.new('http://example.com/')

        expect(parser.call).to eq 'users/sessions#new'
      end
    end
  end
end
