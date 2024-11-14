require 'uri'
require 'net/http'

class Whatsapp::IncomingMessageGupshupService < Whatsapp::IncomingMessageBaseService
  private

  def processed_params
    # Extract essential parts of the Gupshup-specific incoming message
    payload = params[:payload]
    # CUSTOM_LOGGER.info("Processed Params:#{payload}")

    {
      payload: payload,
      message_id: payload[:id], # WhatsApp message ID
      source: payload[:source] || params[:phone_number], # Sender's phone number
      message_type: payload[:type], # Type of message (text, image, etc.)
      content: payload[:payload], # Extract the content based on message type
      context: payload[:context],
      sender: payload[:sender],
      type: payload[:type]
    }
  end

  def extract_content(payload)
    case payload[:type]
    when 'text'
      text_msg = payload[:payload][:text] # Extract text content
      Rails.logger.info("Mil Gaya Text: #{text_msg}")
      text_msg
    when 'image', 'file', 'audio', 'video'
      download_attachment_file(payload[:payload]) # Handle media attachments
    else
      Rails.logger.error("Unsupported message type: #{payload[:type]}")
      nil
    end
  end

  def download_attachment_file(attachment_payload)
    attachment_url = attachment_payload[:url]
    url = URI(attachment_url)

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request['Authorization'] = "Bearer #{inbox.channel.provider_config['api_key']}"

    response = http.request(request)

    if response.code == '200'
      Rails.logger.info('Image response received successfully.')
      Down.download(attachment_url)
    else
      Rails.logger.error("Failed to download attachment. Invalid content type or error in response: #{response.body}")
      nil
    end
  end
end
