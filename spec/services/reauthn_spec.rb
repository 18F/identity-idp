require 'rails_helper'

describe Reauthn do
  describe '#call' do
    context 'reauthn params present' do
      context 'reauthn param is true' do
        it 'is true' do
          param = { reauthn: 'true' }

          expect(Reauthn.new(param).call).to be true
        end
      end

      context 'reauthn param is not true' do
        it 'is false' do
          param = { reauthn: 'other' }

          expect(Reauthn.new(param).call).to be false
        end
      end
    end

    context 'reauthn param not present' do
      it 'is false' do
        param = {}

        expect(Reauthn.new(param).call).to be false
      end
    end
  end
end
