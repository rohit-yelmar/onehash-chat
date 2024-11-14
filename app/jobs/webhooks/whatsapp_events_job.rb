class Webhooks::WhatsappEventsJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    channel = find_channel_from_payload(params)
  
    return if channel_is_inactive?(channel)
    case channel.provider
    when 'whatsapp_cloud'
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: channel.inbox, params: params).perform
    when 'gupshup'
      Whatsapp::IncomingMessageGupshupService.new(inbox: channel.inbox, params: params).perform
    else
      Whatsapp::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    end
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end

  # Determine the channel based on payload type (Gupshup or WhatsApp Cloud)
  def find_channel_from_payload(params)
    if gupshup_payload?(params)
      find_channel_from_gupshup_payload(params)
    else
      find_channel_from_whatsapp_business_payload(params)
    end
  end

  # Check for Gupshup-specific payload structure
  def gupshup_payload?(params)
    # flag = params.dig(:payload, :context, :gsId).present?
    # Rails.logger.info("Chal raha hai kya:#{flag}")
    flag = params[:payload]&.key?('id')
    return flag
  end

  # Method for finding channel using Gupshup payload
  def find_channel_from_gupshup_payload(params)
    app_name = params[:app]  # Extract the app name to identify the channel
    channel = Channel::Whatsapp.where(provider: 'gupshup').where("provider_config->>'app_name' = ?", app_name).first

    channel
  end

  # Method for finding channel using WhatsApp Cloud payload
  def find_channel_from_whatsapp_business_payload(params)
    return get_channel_from_wb_payload(params) if params[:object] == 'whatsapp_business_account'

    find_channel_by_url_param(params)
  end

  # Method remains the same for URL-based channel finding
  def find_channel_by_url_param(params)
    return unless params[:phone_number]

    Channel::Whatsapp.find_by(phone_number: params[:phone_number])
  end

  # For WhatsApp Cloud, identify channel by phone number and phone_number_id
  def get_channel_from_wb_payload(wb_params)
    phone_number = "+#{wb_params[:entry].first[:changes].first.dig(:value, :metadata, :display_phone_number)}"
    phone_number_id = wb_params[:entry].first[:changes].first.dig(:value, :metadata, :phone_number_id)
    channel = Channel::Whatsapp.find_by(phone_number: phone_number)
    # Validate to ensure the phone number ID matches the WhatsApp channel
    return channel if channel && channel.provider_config['phone_number_id'] == phone_number_id
  end
end
