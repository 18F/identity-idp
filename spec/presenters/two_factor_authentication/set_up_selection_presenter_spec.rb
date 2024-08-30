require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpSelectionPresenter do
  include UserAgentHelper

  let(:presenter_class) { TwoFactorAuthentication::SetUpSelectionPresenter }
  let(:user) { build(:user) }
  let(:piv_cac_required) { false }
  let(:phishing_resistant_required) { false }
  let(:user_agent) {}

  subject(:presenter) do
    presenter_class.new(user:, piv_cac_required:, phishing_resistant_required:, user_agent:)
  end

  describe '#render_in' do
    it 'renders captured block content' do
      view_context = ActionController::Base.new.view_context

      expect(view_context).to receive(:capture) do |*_args, &block|
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

  describe '#type' do
    it 'raises with missing implementation' do
      expect { presenter.type }.to raise_error(NotImplementedError)
    end
  end

  describe '#label' do
    it 'raises with missing implementation' do
      expect { presenter.label }.to raise_error(NotImplementedError)
    end
  end

  describe '#info' do
    it 'raises with missing implementation' do
      expect { presenter.info }.to raise_error(NotImplementedError)
    end
  end

  describe '#phishing_resistant?' do
    it 'raises with missing implementation' do
      expect { presenter.phishing_resistant? }.to raise_error(NotImplementedError)
    end
  end

  describe '#visible?' do
    subject(:visible) { presenter.visible? }

    it { expect(visible).to eq(true) }

    context 'with piv cac required' do
      let(:piv_cac_required) { true }

      context 'with non-piv type selection' do
        let(:presenter_class) do
          Class.new(super()) do
            def type
              :not_piv_cac
            end
          end
        end

        it { expect(visible).to eq(false) }
      end

      context 'with piv type selection' do
        let(:presenter_class) do
          Class.new(super()) do
            def type
              :piv_cac
            end
          end
        end

        it { expect(visible).to eq(true) }
      end
    end

    context 'with phishing resistant required' do
      let(:phishing_resistant_required) { true }

      context 'with non-phishing resistant selection' do
        let(:presenter_class) do
          Class.new(super()) do
            def phishing_resistant?
              false
            end
          end
        end

        it { expect(visible).to eq(false) }
      end

      context 'with phishing resistant selection' do
        let(:presenter_class) do
          Class.new(super()) do
            def phishing_resistant?
              true
            end
          end
        end

        it { expect(visible).to eq(true) }
      end
    end

    context 'with selection supporting desktop only' do
      let(:presenter_class) do
        Class.new(super()) do
          def desktop_only?
            true
          end
        end
      end

      it { expect(visible).to eq(true) }

      context 'on mobile device' do
        let(:user_agent) { mobile_user_agent }

        it { expect(visible).to eq(false) }
      end

      context 'on desktop device' do
        let(:user_agent) { desktop_user_agent }

        it { expect(visible).to eq(true) }
      end
    end
  end

  describe '#recommended?' do
    subject(:recommended) { presenter.recommended? }

    it { expect(recommended).to eq(false) }
  end
end
