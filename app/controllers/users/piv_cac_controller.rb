# frozen_string_literal: true

module Users
  class PivCacController < ApplicationController
    include ReauthenticationRequiredConcern
    include PivCacConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa
    before_action :set_form
    before_action :validate_configuration_exists
    before_action :set_presenter

    def edit; end

    def update
      result = form.submit(name: params.dig(:form, :name))

      analytics.piv_cac_update_name_submitted(**result)

      if result.success?
        flash[:success] = presenter.rename_success_alert_text
        redirect_to account_path
      else
        flash.now[:error] = result.first_error_message
        render :edit
      end
    end

    def destroy
      result = form.submit

      analytics.piv_cac_delete_submitted(**result)

      if result.success?
        create_user_event(:piv_cac_disabled)
        revoke_remember_device(current_user)
        clear_piv_cac_information

        flash[:success] = presenter.delete_success_alert_text
        redirect_to account_path
      else
        flash[:error] = result.first_error_message
        redirect_to edit_piv_cac_path(id: params[:id])
      end
    end

    private

    def form
      @form ||= form_class.new(user: current_user, configuration_id: params[:id])
    end

    def presenter
      @presenter ||= TwoFactorAuthentication::PivCacEditPresenter.new
    end

    alias_method :set_form, :form
    alias_method :set_presenter, :presenter

    def form_class
      case action_name
      when 'edit', 'update'
        TwoFactorAuthentication::PivCacUpdateForm
      when 'destroy'
        TwoFactorAuthentication::PivCacDeleteForm
      end
    end

    def validate_configuration_exists
      render_not_found if form.configuration.blank?
    end
  end
end
