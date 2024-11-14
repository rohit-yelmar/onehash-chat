class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  before_action :skip_meta_verification_for_gupshup, only: [:verify]

  def process_payload
    if gupshup_request?
      Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    else
      Rails.logger.info('Processing WhatsApp Cloud webhook payload')
      Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    end
    head :ok
  end

  private

  def skip_meta_verification_for_gupshup
    return unless gupshup_request?

    head :ok  # Skip verification for Gupshup
  end

  def valid_token?(token)
    return false if gupshup_request? # No token validation for Gupshup

    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])

    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  def gupshup_request?
    params[:payload]&.key?('id')
    # return flag
  end

  def process_gupshup_webhook(payload)
    # Implement Gupshup-specific webhook processing logic here
    # Further process the Gupshup webhook data
  end
end
