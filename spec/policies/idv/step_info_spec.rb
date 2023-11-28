# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Idv::StepInfo' do
  let(:controller) { ApplicationController.class }
  let(:next_steps) { [] }
  let(:preconditions) { ->(idv_session:, user:) { true } }
  let(:undo_step) { ->(idv_session:, user:) { true } }
  subject do
    Idv::StepInfo.new(
      key: :my_key,
      controller: controller,
      next_steps: next_steps,
      preconditions: preconditions,
      undo_step: undo_step,
    )
  end

  context 'when given valid arguments' do
    it 'succeeds' do
      expect(subject).to be_valid
    end
  end

  context 'when given an invalid next_steps' do
    let(:next_steps) { 'foo' }

    it 'raises an ArgumentError' do
      expect { subject }.to raise_error(ArgumentError)
    end
  end

  context 'when given an invalid preconditions' do
    let(:preconditions) { 'foo' }

    it 'raises an ArgumentError' do
      expect { subject }.to raise_error(ArgumentError)
    end
  end

  context 'when given an invalid undo_step' do
    let(:preconditions) { 'foo' }

    it 'raises an ArgumentError' do
      expect { subject }.to raise_error(ArgumentError)
    end
  end

  context '#full_controller_name' do
    let(:idv_step_controller_class) do
      Class.new(ApplicationController) do
        def self.name
          'Idv::Lets::Go::Deeper::AnonymousController'
        end
      end
    end

    it 'returns an absolute "path" for the controller name' do
      expect(Idv::StepInfo.full_controller_name(idv_step_controller_class)).
        to eq('/idv/lets/go/deeper/anonymous')
    end
  end
end
