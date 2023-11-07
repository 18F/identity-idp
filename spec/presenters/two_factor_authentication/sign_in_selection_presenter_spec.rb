require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInSelectionPresenter do
  let(:placeholder_presenter_class) do
    Class.new(TwoFactorAuthentication::SignInSelectionPresenter) do
      def method
        :missing
      end
    end
  end

  let(:user) { build(:user) }
  let(:configuration) { create(:phone_configuration, user:) }

  subject(:presenter) { placeholder_presenter_class.new(user:, configuration:) }

  describe '#render_in' do
    it 'renders captured block content' do
      view_context = ActionController::Base.new.view_context

      expect(view_context).to receive(:capture) do |*args, &block|
        expect(block.call).to eq('content')
      end

      presenter.render_in(view_context) { 'content' }
    end
  end

  describe '#label' do
    it 'raises with missing translation' do
      expect do
        presenter.label
      end.to raise_error(RuntimeError)
    end
  end

  describe '#type' do
    it 'returns missing as type' do
      expect(presenter.type).to eq('missing')
    end
  end

  describe '#info' do
    it 'raises with missing translation' do
      expect do
        presenter.info
      end.to raise_error(RuntimeError)
    end
  end
end
