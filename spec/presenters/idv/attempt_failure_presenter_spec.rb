require 'rails_helper'

describe Idv::AttemptFailurePresenter do
  let(:remaining_attempts) { 2 }
  let(:step_name) { :sessions }
  let(:presenter) do
    described_class.new(
      remaining_attempts: remaining_attempts,
      step_name: step_name,
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
end
