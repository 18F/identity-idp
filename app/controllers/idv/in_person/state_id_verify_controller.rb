module Idv
  module InPerson
    class StateIdVerifyController < ApplicationController
      include RenderConditionConcern
      include UspsInPersonProofing

      before_action :confirm_two_factor_authenticated

      def index
        params.slice({
            :first_name,
            :last_name,
            :address1,
            :address2,
            :city,
        }).compact.map do |field|
            result = transliterator.transliterate(field)

        end
      end
    end
  end
end