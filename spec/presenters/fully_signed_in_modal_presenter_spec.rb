require 'rails_helper'

describe FullySignedInModalPresenter do
  subject(:presenter) { FullySignedInModalPresenter.new(10) }

  it 'implements SessionTimeoutWarningModalPresenter' do
    SessionTimeoutWarningModalPresenter.instance_methods(false).each do |method|
      expect(presenter.send(method)).to be
    end
  end
end
