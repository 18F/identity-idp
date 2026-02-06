# frozen_string_literal: true

module Idv
  module InPerson
    class PostOfficeController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern

      def show
        @presenter = Idv::InPerson::PostOfficePresenter.new
      end
    end
  end
end
