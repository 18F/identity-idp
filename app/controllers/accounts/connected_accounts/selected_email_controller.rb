# frozen_string_literal: true

module Accounts
  module ConnectedAccounts
    class SelectedEmailController < ApplicationController
      before_action :confirm_two_factor_authenticated
      before_action :validate_identity

      def edit
        @identity = identity
        @select_email_form = build_select_email_form
        analytics.sp_select_email_visited
      end

      def update
        @select_email_form = build_select_email_form

        result = @select_email_form.submit(form_params)

        analytics.sp_select_email_submitted(**result.to_h)

        if result.success?
          redirect_to account_connected_accounts_path
        else
          flash[:error] = result.first_error_message
          redirect_to edit_connected_account_selected_email_path(identity.id)
        end
      end

      private

      def form_params
        params.require(:select_email_form).permit(:selected_email_id)
      end

      def build_select_email_form
        SelectEmailForm.new(user: current_user, identity:)
      end

      def validate_identity
        render_not_found if identity.blank?
      end

      def identity
        return @identity if defined?(@identity)
        @identity = current_user.identities.find_by(id: params[:identity_id])
      end
    end
  end
end
