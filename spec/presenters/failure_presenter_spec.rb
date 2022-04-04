require 'rails_helper'

describe FailurePresenter do
  let(:state) { :warning }
  let(:presenter) { described_class.new(state) }

  describe '#state' do
    subject { presenter.state }

    it { is_expected.to eq(state) }
  end

  context 'methods with default values of `nil`' do
    %i[title header].each do |method|
      describe "##{method}" do
        subject { presenter.send(method) }

        it { is_expected.to be_nil }
      end
    end

    describe '#description' do
      subject { presenter.description(ActionController::Base.new.view_context) }

      it { is_expected.to be_nil }
    end
  end

  describe '#troubleshooting_options' do
    subject { presenter.troubleshooting_options }

    it { is_expected.to be_empty }
  end

  context 'methods configured by state' do
    %i[icon color].each do |method|
      %i[warning failure locked].each do |state|
        describe "##{method} for #{state}" do
          let(:state) { state }
          subject { presenter.send('state_' + method.to_s) }

          it { is_expected.to eq(config(state, method)) }
        end
      end
    end
  end

  def config(state, key)
    described_class::STATE_CONFIG.dig(state, key)
  end
end
