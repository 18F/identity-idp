# frozen_string_literal: true

class FrontendErrorForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validate :validate_filename_extension
  validate :validate_filename_host

  attr_reader :filename, :error_id

  def submit(filename:, error_id:)
    @filename = filename
    @error_id = error_id

    FormResponse.new(success: valid?, errors:)
  end

  private

  def validate_filename_extension
    return if error_id || File.extname(filename.to_s) == '.js'
    errors.add(:filename, :invalid_extension, message: t('errors.general'))
  end

  def validate_filename_host
    return if error_id

    begin
      return if URI(filename.to_s).host == IdentityConfig.store.domain_name
    rescue URI::InvalidURIError; end

    errors.add(:filename, :invalid_host, message: t('errors.general'))
  end
end
