# frozen_string_literal: true

module IssuerMethods
  extend ActiveSupport::Concern

  def document_images_sharing_allowed?
    IdentityConfig.store.document_images_sharing_enabled &&
      IdentityConfig.store.document_images_sharing_service_providers.include?(issuer)
  end
end
