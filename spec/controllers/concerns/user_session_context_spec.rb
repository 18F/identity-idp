require 'rails_helper'

class DummyController < ApplicationController
  def initialize
    @session = {}
  end

  def set(session)
    @session = session
  end

  def user_session
    @session
  end
end

describe UserSessionContext do
  let(:controller) { DummyController.new }
  let(:confirmation) { { context: 'confirmation' } }

  after { controller.set({}) }

  it 'returns authentication as the default context' do
    expect(controller.context).to eq('authentication')
  end

  it 'returns the correct context when set on session' do
    controller.set(confirmation)
    expect(controller.context).to eq('confirmation')
  end

  context 'user session context predicates' do
    describe '#authentication_context?' do
      it 'returns true when context is authentication, false otherwise' do
        expect(controller.authentication_context?).to be(true)
        expect(controller.confirmation_context?).to be(false)
      end
    end

    describe '#confirmation_context?' do
      it 'returns true if context matches, false otherwise' do
        expect(controller.confirmation_context?).to be(false)

        controller.set(confirmation)

        expect(controller.confirmation_context?).to be(true)
      end
    end
  end
end
