# frozen_string_literal: true

module Accounts
  module DelegatedAccess
    # Advance approval from the account page in two steps: the person selects applications on
    # the delegated access page (`new` shows them with the consent-screen content) and confirms
    # (`create` records the approvals). The selection travels as application ids; anything that
    # is not an active application accepting this service provider, or that the person already
    # has a standing approval for, is dropped before either step.
    class ApprovalsController < ApplicationController
      include DelegatedAccessNotificationConcern

      before_action :confirm_two_factor_authenticated
      before_action :load_service_provider
      before_action :load_applications

      def new
        @presenter = DelegationApprovalPresenter.new(
          service_provider: @service_provider, applications: @applications,
        )
      end

      def create
        grants = AccountDelegationApproval.new(
          user: current_user, service_provider: @service_provider, applications: @applications,
        ).call
        notify_delegation_approved(service_provider: @service_provider, applications: @applications)
        analytics.delegation_account_approved(
          issuer: @service_provider.issuer, applications: grants.map { |g| g.application.issuer },
        )
        flash[:success] = t(
          'account.delegated_access.approved_flash',
          count: grants.size, sp: @service_provider.friendly_name,
        )
        redirect_to account_delegated_access_path(anchor: section_anchor)
      end

      private

      # Only an active service provider currently approved for delegation can receive new
      # approvals; anything else is not found so the registry is not enumerable from here.
      def load_service_provider
        @service_provider = ServiceProvider.active.find_by(id: params[:service_provider_id])
        render_not_found unless @service_provider&.delegation_service_provider?
      end

      # The selected applications, restricted to those this service provider may act at and the
      # person has no current remembered approval for. An empty selection goes back to the page
      # with a notice rather than showing an empty confirmation.
      def load_applications
        accepting = DelegationApplications.accepting(@service_provider.issuer).index_by(&:id)
        selected_ids = Array(params[:application_ids]).map(&:to_i)
        remembered = TokenExchangeGrant.live_by_application(
          user: current_user, service_provider_issuer: @service_provider.issuer,
          applications: accepting.values
        )
        @applications = selected_ids.filter_map { |id| accepting[id] }.reject do |application|
          remembered[application.id]&.remembered_and_current?
        end
        # Both steps read each application's agency: the page groups by it, and each approval
        # records the agency's content version. One query instead of one per application.
        ActiveRecord::Associations::Preloader.new(
          records: @applications,
          associations: :agency,
        ).call
        return if @applications.any?

        flash[:info] = t('account.delegated_access.nothing_selected')
        redirect_to account_delegated_access_path(anchor: section_anchor)
      end

      def section_anchor
        "delegated-access-#{@service_provider.id}"
      end
    end
  end
end
