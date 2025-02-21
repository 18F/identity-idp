# frozen_string_literal: true

module Idv
  class ChooseIdTypeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    def show
    end

    def update
      clear_future_steps!
    end
  end
end
