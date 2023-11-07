require 'rails_helper'

RSpec.describe Test::FakeS3Controller do
  before do
    Test::FakeS3Controller.clear!
  end

  let(:key) { SecureRandom.uuid }
  let(:data) { SecureRandom.random_bytes }

  describe '#show' do
    subject(:action) { get :show, params: { key: } }

    context 'with a valid key' do
      before { Test::FakeS3Controller.data[key] = data }

      it 'is that data' do
        action

        expect(response.body).to eq(data)
      end
    end

    context 'with an unknown key' do
      it '404s' do
        action

        expect(response).to be_not_found
      end
    end
  end

  describe '#update' do
    subject(:action) do
      post :update, body: data, params: { key: }
    end

    it 'stores the data in memory' do
      expect { action }.
        to(change { Test::FakeS3Controller.data[key] }.to(data))
    end
  end
end
