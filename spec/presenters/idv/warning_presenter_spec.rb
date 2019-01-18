require 'rails_helper'

describe Idv::WarningPresenter do
  let(:reason) { :warning }
  let(:remaining_attempts) { 2 }
  let(:step_name) { :sessions }
  let(:view_context) { mock_view_context }
  let(:presenter) do
    described_class.new(
      reason: reason,
      remaining_attempts: remaining_attempts,
      step_name: step_name,
      view_context: view_context,
    )
  end

  describe 'it uses the :warning failure state' do
    subject { presenter.state }

    it { is_expected.to eq(:warning) }
  end

  context 'methods are overriden' do
    %i[title header description].each do |method|
      describe "##{method}" do
        subject { presenter.send(method) }

        it { is_expected.to_not be_nil }
      end
    end
  end

  describe '#warning_message' do
    context 'when `reason == :warning`' do
      let(:reason) { :warning }

      subject { presenter.warning_message }

      it { is_expected.to eq(presenter.send(:warning)) }
    end

    context 'when `reason != :warning`' do
      let(:reason) { :fail }

      subject { presenter.warning_message }

      it { is_expected.to eq(presenter.send(:error)) }
    end
  end

  describe '#button_path' do
    context 'when `step_name == :sessions`' do
      let(:step_name) { :sessions }

      subject { presenter.button_path }

      it { is_expected.to eq(view_context.idv_session_path) }
    end

    context 'when `step_name != :sessions`' do
      let(:step_name) { :phone }

      subject { presenter.button_path }

      it { is_expected.to eq(view_context.idv_phone_path) }
    end
  end

  describe '#warning' do
    subject { presenter.send(:warning) }

    it 'includes the number of remaining attempts' do
      expect(subject).to include(remaining_attempts.to_s)
    end
  end

  describe '#error' do
    subject { presenter.send(:error) }

    it 'includes the contact url' do
      expect(subject).to include(MarketingSite.contact_url)
    end
  end

  def mock_view_context
    view_context = ActionView::Base.new
    allow(view_context).to receive(:idv_phone_path).and_return('idv phone path')
    allow(view_context).to receive(:idv_session_path).and_return('idv session path')
    view_context
  end
end
