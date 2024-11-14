require 'uri'
require 'net/http'

class Whatsapp::Providers::GupshupService < Whatsapp::Providers::BaseService
  GUPSHUP_API_URL = "https://api.gupshup.io/wa/api/v1/msg"
  GUPSHUP_API_TEMPLATE_URL = "https://api.gupshup.io/wa/api/v1/template/msg"

  def send_message(phone_number, message)
    if message.attachments.present?
      Rails.logger.info("Attachment present")
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      Rails.logger.info("Message #{message} Number: #{phone_number}")
      Rails.logger.info("Plain message Gaya")
      send_text_message(phone_number, message)
    end
  end

  def send_template(phone_number, template_info)
    uri = URI(GUPSHUP_API_TEMPLATE_URL)
    request = Net::HTTP::Post.new(uri)

    request["content-type"] = 'application/x-www-form-urlencoded'
    request["apikey"] = whatsapp_channel.provider_config['api_key']
    text_parameters = template_info[:parameters].map { |param| param[:text] }
    source_number = whatsapp_channel.provider_config['source'].gsub(/\D/, '')
    temp =  {
      id: template_info[:namespace],  # Assuming template_info contains the template ID as `id`
      params: text_parameters # Assuming `parameters` is already an array of strings
      }.to_json

    request.body = URI.encode_www_form({
      channel: 'whatsapp',
      source: source_number,
      destination: phone_number,
      "src.name": whatsapp_channel.provider_config['app_name'],
      template: temp
    })


    process_request(uri, request)
  end

  def sync_templates
    app_id = whatsapp_channel.provider_config['app_id']
    api_key = whatsapp_channel.provider_config['api_key']
    CUSTOM_LOGGER.info("Syncing templates")
    # Construct the URL for fetching all templates
    url = URI("https://api.gupshup.io/wa/app/#{app_id}/template")
  
    # Create the HTTP request
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
  
    request = Net::HTTP::Get.new(url)
    request["accept"] = 'application/json'
    request["apikey"] = api_key
  
    # Execute the request
    response = http.request(request)
  
    if response.code.to_i == 200
      templates = JSON.parse(response.body)
      if templates.present?
        # Update the templates in the channel
        whatsapp_channel.update(
          message_templates: templates,
          message_templates_last_updated: Time.now.utc
        )
        whatsapp_channel.mark_message_templates_updated
        CUSTOM_LOGGER.info("Updated message templates: #{templates}")
      end
    else
      # Log the error or handle it appropriately
      CUSTOM_LOGGER.info("Failed to sync templates: #{response.body}")
    end
  end
  
  

  def validate_provider_config?
    # You can implement Gupshup's equivalent of validating the config, if available
    true
  end

  def send_text_message(phone_number, message)
    uri = URI(GUPSHUP_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = 'application/x-www-form-urlencoded'
    request["apikey"] = whatsapp_channel.provider_config['api_key']
    Rails.logger.info("APIKEY: #{whatsapp_channel.provider_config['api_key']}")
    Rails.logger.info("Config bhi set ho gya: #{message.content}")
    source_number = whatsapp_channel.provider_config['source'].gsub(/\D/, '') # Removes non-numeric characters
  source_number = "#{source_number}" # Prefix '91' and ensure it's the last 10 digits

    Rails.logger.info("Source No: #{source_number} App Name: #{whatsapp_channel.provider_config['app_name']}")
    request.body = URI.encode_www_form({
      channel: 'whatsapp',
      source: source_number,
      "src.name": whatsapp_channel.provider_config['app_name'],
      destination: phone_number,
      message: {
        type: 'text',
        text: message.content
      }.to_json
    })
    Rails.logger.info("Request: #{request.body}")
    Rails.logger.info("Send ho gya message")
    process_request(uri, request)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    Rails.logger.info("Attachment: #{attachment}")
    file_type = attachment.file_type
    Rails.logger.info("File Type: #{file_type}")
    # Set the message type based on the attachment's file_type
    # ngrok_url = 'https://1348-2401-4900-1c55-7420-bcd3-2127-d2b8-d1c.ngrok-free.app'

    # # Replace the local URL with the Ngrok URL
    # public_url = attachment.download_url.gsub('http://localhost:3000', ngrok_url)
    # Rails.logger.info("Public URL: #{public_url}")
    message_payload = case file_type
                      when 'image'
                        {
                          type: 'image',
                          originalUrl: attachment.download_url,
                          previewUrl: attachment.download_url,
                          caption: message.content
                        }
                      when 'document'
                        {
                          type: 'file',
                          url: attachment.download_url,
                          filename: attachment.filename || 'document',
                          caption: message.content
                        }
                      when 'video'
                        {
                          type: 'video',
                          url: attachment.download_url,
                          caption: message.content
                        }
                      when 'audio'
                        {
                          type: 'audio',
                          url: attachment.download_url
                        }
                      else
                        {
                          type: 'file',
                          url: attachment.download_url,
                          filename: 'docu',
                          caption: message.content
                        }
                      end
  
    uri = URI(GUPSHUP_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = 'application/x-www-form-urlencoded'
    request["accept"] = 'application/json'
    request["apikey"] = whatsapp_channel.provider_config['api_key']
    source_number = whatsapp_channel.provider_config['source'].gsub(/\D/, '')
    Rails.logger.info("Source: #{source_number}")
    request.body = URI.encode_www_form({
      channel: 'whatsapp',
      source: source_number,
      "src.name": whatsapp_channel.provider_config['app_name'],
      destination: phone_number,
      message: message_payload.to_json
    })
    Rails.logger.info("Send ho gya message")
    process_request(uri, request)
  end
  

  def send_interactive_text_message(phone_number, message)
    uri = URI(GUPSHUP_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = 'application/x-www-form-urlencoded'
    
    request["apikey"] = whatsapp_channel.provider_config['api_key']

    request.body = URI.encode_www_form({
      channel: 'whatsapp',
      source: whatsapp_channel.provider_config['source'],
      destination: phone_number,
      message: {
        type: 'interactive',
        interactive: create_payload_based_on_items(message)
      }.to_json
    })

    process_request(uri, request)
  end

  private

  def process_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)
    Rails.logger.info("idhar pahuch gye")
    if response.code.to_i == 200
      Rails.logger.info("Message successfull")
      JSON.parse(response.body)['messageId']
    else
      CUSTOM_LOGGER.info("Response: #{response.body}")
      nil
      
    end
  end
end
