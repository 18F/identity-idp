# frozen_string_literal: true

class SocureErrorPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TranslationHelper
  include LinkHelper

  attr_reader :url_options

  def initialize(error_code:, remaining_attempts:, sp_name:, issuer:, flow_path:)
    @error_code = error_code
    @remaining_attempts = remaining_attempts
    @sp_name = sp_name
    @issuer = issuer
    @flow_path = flow_path
    @url_options = {}
  end

  def heading
    heading_string_for(error_code)
  end

  def body_text
    error_string_for(error_code)
  end

  def rate_limit_text
    return if error_code == :url_not_found # Not showing rate limit if capture app url not found
  
    if remaining_attempts == 1
      t('doc_auth.rate_limit_warning.singular_html')
    else
      t('doc_auth.rate_limit_warning.plural_html', remaining_attempts: remaining_attempts)
    end
  end

  def action
    url = flow_path == :hybrid ? idv_hybrid_mobile_socure_document_capture_path
                               : idv_socure_document_capture_path
    {
      text: I18n.t('idv.failure.button.warning'),
      url:,
    }
  end

  def secondary_action_heading
    I18n.t('in_person_proofing.headings.cta')
  end

  def secondary_action_text
    I18n.t('in_person_proofing.body.cta.prompt_detail')
  end

  def secondary_action
    url = flow_path == :hybrid ? idv_hybrid_mobile_in_person_direct_url :
                                  idv_in_person_direct_url

    if in_person_enabled?
      {
        text: I18n.t('in_person_proofing.body.cta.button'),
        url:,
      }
    end
  end

  def troubleshooting_heading
    I18n.t('components.troubleshooting_options.ipp_heading')
  end

  def options
    return [] if error_code == :timeout || error_code == :url_not_found

    [
      {
        url: help_center_redirect_path(
          category: 'verify-your-identity',
          article: 'how-to-add-images-of-your-state-issued-id',
        ),
        text: I18n.t('idv.troubleshooting.options.doc_capture_tips'),
        isExternal: true,
      },
      {
        url: help_center_redirect_path(
          category: 'verify-your-identity',
          article: 'accepted-identification-documents',
        ),
        text: I18n.t('idv.troubleshooting.options.supported_documents'),
        isExternal: true,
      },
      {
        url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
        text: t(
          'idv.failure.verify.fail_link_html',
          sp_name: sp_name,
        ),
        isExternal: true,
      },
    ]
  end

  def step_indicator_steps
    Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS
  end

  private

  attr_reader :error_code, :remaining_attempts, :sp_name, :issuer, :flow_path

  SOCURE_ERROR_MAP = {
    'I848' => 'unreadable_id',
    'I854' => 'unreadable_id',
    'R810' => 'unreadable_id',
    'R820' => 'unreadable_id',
    'R822' => 'unreadable_id',
    'R823' => 'unreadable_id',
    'R824' => 'unreadable_id',
    'R825' => 'unreadable_id',
    'R826' => 'unreadable_id',
    'R831' => 'unreadable_id',
    'R833' => 'unreadable_id',
    'R838' => 'unreadable_id',
    'R859' => 'unreadable_id',
    'R861' => 'unreadable_id',
    'R863' => 'unreadable_id',

    'I849' => 'unaccepted_id_type',
    'R853' => 'unaccepted_id_type',
    'R862' => 'unaccepted_id_type',

    'R827' => 'expired_id',

    'I808' => 'low_resolution',

    'R845' => 'underage',

    'I856' => 'id_not_found',
    'R819' => 'id_not_found',
  }.freeze

  def remapped_error(error_code)
    SOCURE_ERROR_MAP[error_code] || 'unreadable_id'
  end

  def heading_string_for(error_code)
    case error_code
    when :network
      t('doc_auth.headers.general.network_error')
    when :timeout, :url_not_found
      t('idv.errors.technical_difficulties')
    else
      # i18n-tasks-use t('doc_auth.headers.unreadable_id')
      # i18n-tasks-use t('doc_auth.headers.unaccepted_id_type')
      # i18n-tasks-use t('doc_auth.headers.expired_id')
      # i18n-tasks-use t('doc_auth.headers.low_resolution')
      # i18n-tasks-use t('doc_auth.headers.underage')
      # i18n-tasks-use t('doc_auth.headers.id_not_found')
      I18n.t("doc_auth.headers.#{remapped_error(error_code)}")
    end
  end

  def error_string_for(error_code)
    case error_code
    when :network
      t('doc_auth.errors.general.new_network_error')
    when :timeout, :url_not_found
      t('idv.errors.try_again_later')
    else
      if remapped_error(error_code) == 'underage' # special handling because it says 'Login.gov'
        I18n.t('doc_auth.errors.underage', app_name: APP_NAME)
      else
        # i18n-tasks-use t('doc_auth.errors.unreadable_id')
        # i18n-tasks-use t('doc_auth.errors.unaccepted_id_type')
        # i18n-tasks-use t('doc_auth.errors.expired_id')
        # i18n-tasks-use t('doc_auth.errors.low_resolution')
        # i18n-tasks-use t('doc_auth.errors.id_not_found')
        I18n.t("doc_auth.errors.#{remapped_error(error_code)}")
      end
    end
  end

  def in_person_enabled?
    IdentityConfig.store.in_person_doc_auth_button_enabled &&
      Idv::InPersonConfig.enabled_for_issuer?(issuer)
  end
end
