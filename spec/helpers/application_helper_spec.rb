require 'rails_helper'

describe ApplicationHelper do
  describe '#session_with_trust?' do
    context 'no user present' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      context 'current path is new session path' do
        it 'returns false' do
          allow(helper).to receive(:current_page?).with(
            controller: 'users/sessions', action: 'new',
          ).and_return(true)

          expect(helper.session_with_trust?).to eq false
        end
      end

      context 'current path is not new session path' do
        it 'returns true' do
          allow(helper).to receive(:current_page?).with(
            controller: 'users/sessions', action: 'new',
          ).and_return(false)

          expect(helper.session_with_trust?).to eq true
        end
      end
    end

    context 'curent user is present' do
      it 'returns true' do
        allow(controller).to receive(:current_user).and_return(true)

        expect(helper.session_with_trust?).to eq true
      end
    end
  end
end
