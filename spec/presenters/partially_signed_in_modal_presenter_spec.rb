require 'rails_helper'

describe PartiallySignedInModalPresenter do
  subject(:presenter) { PartiallySignedInModalPresenter.new(10) }

  it 'implements SessionTimeoutWarningModalPresenter' do
    SessionTimeoutWarningModalPresenter.instance_methods(false).each do |method|
      expect(presenter.send(method)).to be
    end
  end
end
