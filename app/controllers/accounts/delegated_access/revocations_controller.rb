# frozen_string_literal: true

module Accounts
  module DelegatedAccess
    # Revocation from the account page, always through a confirmation page, at one of three
    # scopes decided by the route: one application of a service provider, everything for a
    # service provider, or everything the person has approved for any service provider.
    class RevocationsController < ApplicationController
      include DelegatedAccessNotificationConcern

      before_action :confirm_two_factor_authenticated
      before_action :load_scope

      def show
        return redirect_to account_delegated_access_path if @revocation.grants.empty?

        @applications = @revocation.grants.map(&:application)
        # When the revocation spans every service provider the page names each row's service
        # provider, so those records are loaded in one query rather than one per row.
        return if @service_provider

        ActiveRecord::Associations::Preloader.new(
          records: @revocation.grants, associations: :service_provider_record,
        ).call
      end

      def destroy
        revoked = @revocation.call
        if revoked.any?
          applications = revoked.map(&:application)
          notify_delegation_revoked(service_provider: @service_provider, applications:)
          analytics.delegation_account_revoked(
            issuer: @service_provider&.issuer,
            applications: applications.map(&:issuer),
            scope: @revocation.scope_name,
          )
          flash[:success] = t('account.delegated_access.revoked_flash', count: revoked.size)
        end
        redirect_to account_delegated_access_path
      end

      private

      # The service provider and application come from the route when present. A service
      # provider that is no longer approved or active can still be revoked, so only existence is
      # checked here; the application must be one of its applications with a live approval, which
      # the revocation's own scope enforces.
      def load_scope
        if params[:service_provider_id].present?
          @service_provider = ServiceProvider.find_by(id: params[:service_provider_id])
          return render_not_found if @service_provider.nil?
        end
        if params[:application_id].present?
          @application = ServiceProvider.find_by(id: params[:application_id])
          return render_not_found if @application.nil?
        end
        @revocation = AccountDelegationRevocation.new(
          user: current_user, service_provider: @service_provider, application: @application,
        )
      end
    end
  end
end
