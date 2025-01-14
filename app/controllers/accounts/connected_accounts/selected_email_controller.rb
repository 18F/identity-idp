# frozen_string_literal: true

module Accounts
  module ConnectedAccounts
    class SelectedEmailController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.feature_select_email_to_share_enabled }
      before_action :confirm_two_factor_authenticated
      before_action :validate_identity

      def edit
        @identity = identity
        @select_email_form = build_select_email_form
        @can_add_email = EmailPolicy.new(current_user).can_add_email?
        analytics.sp_select_email_visited
        @email_id = @identity.email_address_id || last_email_id
      end

      def update
        @select_email_form = build_select_email_form

        result = @select_email_form.submit(selected_email_id: selected_email_id)

        analytics.sp_select_email_submitted(**result)

        if result.success?
          flash[:email_updated_identity_id] = identity.id
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

      def selected_email_id
        if identity.sp_only_single_email_requested?
          form_params[:selected_email_id]
        end
      end

      def last_email_id
        current_user.last_sign_in_email_address.id
      end
    end
  end
end
