module Users
  class RulesOfUseController < ApplicationController
    before_action :confirm_signed_in
    before_action :confirm_need_to_accept_rules_of_use

    def new
      analytics.rules_of_use_visit
      @rules_of_use_form = new_rules_of_use_form
      render :new, formats: :html
    end

    def create
      @rules_of_use_form = new_rules_of_use_form

      result = @rules_of_use_form.submit(permitted_params)

      analytics.rules_of_use_submitted(**result.to_h)

      if result.success?
        process_successful_agreement_to_rules_of_use
      else
        render :new
      end
    end

    private

    def new_rules_of_use_form
      RulesOfUseForm.new(current_user)
    end

    def process_successful_agreement_to_rules_of_use
      redirect_to user_two_factor_authentication_url
    end

    def confirm_signed_in
      return if signed_in?
      redirect_to root_url
    end

    def confirm_need_to_accept_rules_of_use
      return unless current_user.accepted_rules_of_use_still_valid?

      redirect_to user_two_factor_authentication_url
    end

    def permitted_params
      params.require(:rules_of_use_form).permit(:terms_accepted)
    end
  end
end
