require 'rails_helper'

describe ParseControllerFromReferer do
  describe '#call' do
    context 'when the referer is nil' do
      it 'returns "no referer" string' do
        parser = ParseControllerFromReferer.new(nil)
        result = { request_came_from: 'no referer' }

        expect(parser.call).to eq result
      end
    end

    context 'when the referer is present' do
      it 'returns the corresponding controller and action' do
        parser = ParseControllerFromReferer.new('http://example.com/')
        result = { request_came_from: 'users/sessions#new' }

        expect(parser.call).to eq result
      end
    end
  end
end
