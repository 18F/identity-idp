require 'rails_helper'

describe Idv::SsnFailurePresenter do
  let(:view_context) { mock_view_context }
  let(:presenter) { described_class.new(view_context: view_context) }

  describe 'it uses the :failure failure state' do
    subject { presenter.state }

    it { is_expected.to eq(:failure) }
  end

  context 'methods are overriden' do
    %i[title header description message].each do |method|
      describe "##{method}" do
        subject { presenter.send(method) }

        it { is_expected.to_not be_nil }
      end
    end
  end

  describe '#next_steps' do
    subject { presenter.next_steps }

    it 'is empty' do
      expect(subject).to eq([])
    end
  end

  describe '#try_again_step' do
    subject { presenter.send(:try_again_step) }

    it 'includes session path' do
      expect(subject).to include(view_context.idv_session_path)
    end
  end

  describe '#sign_out_step' do
    subject { presenter.send(:sign_out_step) }

    it 'includes sign_out url' do
      expect(subject).to include(view_context.destroy_user_session_path)
    end
  end

  describe '#profile_step' do
    subject { presenter.send(:profile_step) }

    it 'includes profile url' do
      expect(subject).to include(view_context.account_path)
    end
  end

  def mock_view_context
    view_context = ActionView::Base.new
    allow(view_context).to receive(:account_path).and_return('account path')
    allow(view_context).to receive(:destroy_user_session_path).and_return('sign out path')
    allow(view_context).to receive(:idv_session_path).and_return('idv session path')
    view_context
  end
end
