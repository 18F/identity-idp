require 'rails_helper'

describe AccountReset::PendingController do
  describe '#show' do
    it 'renders'

    context 'when the account reset request does not exist' do
      it 'renders a 404'
    end
  end

  describe '#cancel' do
    it 'cancels the account reset request'

    context 'when the account reset request does not exist' do
      it 'renders a 404'
    end
  end
end
