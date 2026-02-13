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

      def search
        @presenter = Idv::InPerson::PostOfficePresenter.new
        @post_offices = [{
          address: 'Happy Lane',
          city: 'Qwertyton',
          distance: 1.28,
          name: 'Happy Post Office',
          saturday_hours: '1:00 - 2:00',
          state: 'PA',
          sunday_hours: '1:00 - 2:00',
          weekday_hours: '1:00 - 2:00',
          zip_code_4: '4633',
          zip_code_5: '12345',
        }, {
          address: 'Happy Lane',
          city: 'Qwertyton',
          distance: 1.28,
          name: 'Happy Post Office',
          saturday_hours: '1:00 - 2:00',
          state: 'PA',
          sunday_hours: '1:00 - 2:00',
          weekday_hours: '1:00 - 2:00',
          zip_code_4: '4633',
          zip_code_5: '12345',
        }]
      end
    end
  end
end
