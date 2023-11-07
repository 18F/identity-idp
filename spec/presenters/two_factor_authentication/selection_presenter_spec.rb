require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SelectionPresenter do
  let(:placeholder_presenter_class) do
    Class.new(TwoFactorAuthentication::SelectionPresenter) do
      def method
        :missing
      end
    end
  end

  let(:user) { build(:user) }

  subject(:presenter) { described_class.new(user:) }

  describe '#render_in' do
    it 'renders captured block content' do
      view_context = ActionController::Base.new.view_context

      expect(view_context).to receive(:capture) do |*args, &block|
        expect(block.call).to eq('content')
      end

      presenter.render_in(view_context) { 'content' }
    end
  end

  describe '#disabled?' do
    let(:single_configuration_only) {}
    let(:mfa_configuration_count) {}

    before do
      allow(presenter).to receive(:single_configuration_only?).and_return(single_configuration_only)
      allow(presenter).to receive(:mfa_configuration_count).and_return(mfa_configuration_count)
    end

    context 'without single configuration restriction' do
      let(:single_configuration_only) { false }

      it 'is an mfa that allows multiple configurations' do
        expect(presenter.disabled?).to eq(false)
      end
    end

    context 'with single configuration only' do
      let(:single_configuration_only) { true }

      context 'with default mfa count implementation' do
        before do
          allow(presenter).to receive(:mfa_configuration_count).and_call_original
        end

        it 'is mfa with unimplemented mfa count and single config' do
          expect(presenter.disabled?).to eq(false)
        end
      end

      context 'with no configured mfas' do
        let(:mfa_configuration_count) { 0 }

        it 'is configured with no mfa' do
          expect(presenter.disabled?).to eq(false)
        end
      end

      context 'with at least one configured mfa' do
        let(:mfa_configuration_count) { 1 }

        it 'is mfa with at least one configured' do
          expect(presenter.disabled?).to eq(true)
        end
      end
    end
    context 'with configuration' do
      let(:single_configuration_only) { true }
      let(:mfa_configuration_count) { 1 }
      let(:configuration) { create(:phone_configuration, user:) }
      before do
        allow(presenter).to receive(:configuration).and_return(configuration)
      end
      it { expect(presenter.disabled?).to eq(false) }
    end
  end

  describe '#single_configuration_only?' do
    it { expect(presenter.single_configuration_only?).to eq(false) }
  end

  describe '#mfa_added_label' do
    subject(:mfa_added_label) { presenter.mfa_added_label }
    before do
      allow(presenter).to receive(:mfa_configuration_count).and_return('1')
    end
    it 'is a count of configured MFAs' do
      expect(presenter.mfa_added_label).to include('added')
    end

    context 'with single configuration only' do
      before do
        allow(presenter).to receive(:single_configuration_only?).and_return(true)
      end

      it 'is an empty string' do
        expect(presenter.mfa_added_label).to eq('')
      end
    end
  end

  describe '#label' do
    context 'with no configuration' do
      it 'raises with missing translation' do
        expect { placeholder_presenter_class.new(user:).label }.to raise_error(RuntimeError)
      end
    end

    context 'with configuration' do
      it 'raises with missing translation' do
        expect do
          placeholder_presenter_class.new(configuration: 1, user:).label
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe '#info' do
    context 'with no configuration' do
      it 'raises with missing translation' do
        expect { placeholder_presenter_class.new(user:).info }.to raise_error(RuntimeError)
      end
    end

    context 'with configuration' do
      it 'raises with missing translation' do
        expect do
          placeholder_presenter_class.new(configuration: 1, user:).info
        end.to raise_error(RuntimeError)
      end
    end
  end
end
