require 'rails_helper'

describe Idv::ForgotPasswordPresenter do
  let(:decorated_session) { mock_decorated_session }
  let(:view_context) { mock_view_context }
  let(:presenter) { described_class.new(view_context: view_context) }

  describe 'it uses the :are_you_sure failure state' do
    subject { presenter.state }

    it { is_expected.to eq(:are_you_sure) }
  end

  describe '#title' do
    subject { presenter.send(:title) }

    it 'includes the title' do
      expect(subject).to eq(t('idv.forgot_password.modal_header'))
    end
  end

  describe '#header' do
    subject { presenter.send(:header) }

    it 'includes the header' do
      expect(subject).to eq(t('idv.forgot_password.modal_header'))
    end
  end

  def mock_view_context
    view_context = ActionView::Base.new
    allow(view_context).to receive(:account_path).and_return('Account Path')
    allow(view_context).to receive(:decorated_session).and_return(mock_decorated_session)
    view_context
  end

  def mock_decorated_session
    decorated_session = instance_double(SessionDecorator)
    allow(decorated_session).to receive(:sp_name).and_return('Test SP')
    allow(decorated_session).to receive(:sp_return_url).and_return('SP Link')
    decorated_session
  end
end
