# frozen_string_literal: true

class MultipleAccountsDetectedController < ApplicationController
    before_action :confirm_two_factor_authenticated
  
    def show
    end
  
    def skip
    end

    def own_all_accounts

    end
  end
  