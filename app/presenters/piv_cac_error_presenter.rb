# frozen_string_literal: true

class PivCacErrorPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  attr_accessor :error

  def initialize(error:, view:, try_again_url:)
    @error = error
    @view = view
    @try_again_url = try_again_url
  end

  def title
    heading
  end

  def heading
    case error
    when 'piv_cac.already_associated'
      t('headings.piv_cac_setup.already_associated')
    when 'user.not_found'
      t('headings.piv_cac_login.account_not_found')
    when 'certificate.bad'
      t('headings.piv_cac.certificate.bad')
    when 'certificate.expired'
      t('headings.piv_cac.certificate.expired')
    when 'certificate.invalid'
      t('headings.piv_cac.certificate.invalid')
    when 'certificate.none'
      t('headings.piv_cac.certificate.none')
    when 'certificate.not_auth_cert'
      t('headings.piv_cac.certificate.not_auth_cert')
    when 'certificate.revoked'
      t('headings.piv_cac.certificate.revoked')
    when 'certificate.unverified'
      t('headings.piv_cac.certificate.unverified')
    when 'token.bad'
      t('headings.piv_cac.token.bad')
    when 'token.invalid'
      t('headings.piv_cac.token.invalid')
    when 'token.missing', 'token.http_failure'
      t('headings.piv_cac.token.missing')
    else
      t('headings.piv_cac.did_not_work')
    end
  end

  def description
    case error
    when 'piv_cac.already_associated'
      t('instructions.mfa.piv_cac.already_associated_html', try_again_html: try_again_link)
    when 'user.not_found'
      t(
        'instructions.mfa.piv_cac.account_not_found_html',
        app_name: APP_NAME,
        sign_in: @view.link_to(t('headings.sign_in_without_sp'), root_url),
        create_account: @view.link_to(t('links.create_account'), sign_up_email_url),
      )
    when 'certificate.none'
      t('instructions.mfa.piv_cac.no_certificate_html', try_again_html: try_again_link)
    when 'certificate.not_auth_cert'
      t('instructions.mfa.piv_cac.not_auth_cert_html', please_try_again_html: please_try_again_link)
    when 'token.http_failure'
      t('instructions.mfa.piv_cac.http_failure')
    else
      t('instructions.mfa.piv_cac.did_not_work_html', please_try_again_html: please_try_again_link)
    end
  end

  def url_options
    @view.url_options
  end

  def troubleshooting_options
    [
      choose_another_method_troubleshooting_option,
      issues_with_piv_cac_troubleshooting_option,
      how_add_or_change_authenticator_troubleshooting_option,
    ]
  end

  def choose_another_method_troubleshooting_option
    BlockLinkComponent.new(url: login_two_factor_options_path)
      .with_content(t('two_factor_authentication.login_options_link_text'))
  end
  
  def issues_with_piv_cac_troubleshooting_option
    BlockLinkComponent.new(
      url: MarketingSite.help_center_article_url(
        category: 'trouble-signing-in',
        article: 'authentication/issues-with-government-employee-id-piv-cac',
      ),
      new_tab: true,
    ).with_content(t('instructions.mfa.piv_cac.issues_with_piv_cac'))
  end
  
  def how_add_or_change_authenticator_troubleshooting_option
    BlockLinkComponent.new(
      url: help_center_redirect_path(
        category: 'manage-your-account',
        article: 'add-or-change-your-authentication-method',
        flow: :two_factor_authentication,
        step: redirect_location_step,
      ),
      new_tab: true,
    ).with_content(t('two_factor_authentication.add_or_change_authenticator'))
  end

  private

  def please_try_again_link
    @view.link_to(t('instructions.mfa.piv_cac.please_try_again'), @try_again_url)
  end

  def try_again_link
    @view.link_to(t('instructions.mfa.piv_cac.try_again'), @try_again_url)
  end
end
