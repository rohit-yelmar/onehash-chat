# Mostly modeled after the intial implementation of the service based on 360 Dialog
# https://docs.360dialog.com/whatsapp-api/whatsapp-api/media
# https://developers.facebook.com/docs/whatsapp/api/media/
class Whatsapp::IncomingMessageBaseService
  include ::Whatsapp::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    @processed_params = processed_params

    if processed_params.key?(:message_id) && processed_params.key?(:content)

      process_gupshup_messages
    elsif processed_params.try(:[], :messages).present?
      process_messages
    elsif processed_params.try(:[], :statuses).present?
      process_statuses
    end
  end

  private

  def process_gupshup_messages
    return if unprocessable_message_type?(processed_params[:message_type])

    # Ensure no duplicate messages are processed
    return if find_message_by_source_id(processed_params[:message_id])

    cache_message_source_id_in_redis

    set_contact_for_gupshup

    return unless @contact

    set_conversation

    create_gupshup_messages

    clear_message_source_id_from_redis
  end

  def create_gupshup_messages
    message = processed_params
    log_error(message) && return if error_webhook_event?(message)

    process_in_reply_to(message)

    message[:message_type] == 'contacts' ? create_contact_messages(message) : create_regular_gupshup_message(message)
  end

  def create_regular_gupshup_message(message)
    create_message_for_gupshup(message)

    message[:message_type] == 'location' ? attach_location_for_gupshup : attach_files_for_gupshup
    @message.save!
  end

  def create_message_for_gupshup(message)
    # Extract fields specifically for Gupshup payload structure

    content = message[:content][:text] || 'Attachment'
    source_id = message[:message_id] || 'No message ID'

    payload = message[:payload]

    source_id = payload[:gsId] if message[:type] == 'sent' || message[:type] == 'read'

    @message = @conversation.messages.build(
      content: content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: source_id.to_s,
      in_reply_to_external_id: @in_reply_to_external_id
    )
  end

  def attach_location_for_gupshup
    location = @processed_params[:content]
    location_name = 'Location' # Dummy Name
    type = file_content_type(processed_params[:message_type])
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: type,
      coordinates_lat: location[:latitude],
      coordinates_long: location[:longitude],
      fallback_title: location_name,
      external_url: 'Dummy_url' # Dummy_url
    )
  end

  def attach_files_for_gupshup
    # Return early if the message type doesn't involve an attachment
    return if %w[text button interactive location contacts].include?(processed_params[:message_type])

    attachment_payload = processed_params

    # Set the message content if there is a caption in the payload
    @message.content ||= attachment_payload[:content][:caption] if attachment_payload[:content][:caption].present?

    # Check if the content has a valid URL for the attachment
    attachment_url = attachment_payload.dig(:content, :url)
    return unless attachment_url.present? && attachment_url =~ URI::DEFAULT_PARSER.make_regexp

    # Download the file from the attachment URL
    attachment_file = download_attachment_file(attachment_payload[:content])

    return if attachment_file.blank?

    type = file_content_type(attachment_payload[:message_type])

    # Attach the downloaded file to the message

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: type,
      file: {
        io: attachment_file,
        filename: attachment_payload[:content][:caption] || 'unknown.jpg', # Fallback filename
        content_type: attachment_payload[:content][:contentType] || 'image/jpeg' # Fallback content type
      }
    )
  end

  def set_contact_for_gupshup
    # identifier = processed_params[:context]['gsId']
    # identifier = identifier.to_s.gsub(/\D/, '').slice(0, 15)
    # Rails.logger.info("Identifier for Gupshup: #{identifier}")

    # Strip out any non-numeric characters if necessary
    source_number = if processed_params[:source].present?
                      CUSTOM_LOGGER.info('Using :source')
                      processed_params[:source].gsub(/\D/, '') || processed_params[:sender]['phone']
                    else
                      CUSTOM_LOGGER.info('Using destination')
                      processed_params.dig(:payload, 'destination').to_s.gsub(/\D/, '')
                    end

    # Use dig to safely access the name or fallback to 'unknown'
    source_name = processed_params.dig(:sender, 'name') || 'unknown'

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: source_number,
      inbox: inbox,
      contact_attributes: { name: source_name, phone_number: "+#{source_number}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def process_messages
    # We don't support reactions & ephemeral message now, we need to skip processing the message
    # if the webhook event is a reaction or an ephermal message or an unsupported message.
    return if unprocessable_message_type?(message_type)

    # Multiple webhook event can be received against the same message due to misconfigurations in the Meta
    # business manager account. While we have not found the core reason yet, the following line ensure that
    # there are no duplicate messages created.
    return if find_message_by_source_id(@processed_params[:messages].first[:id]) || message_under_process?

    cache_message_source_id_in_redis
    set_contact
    return unless @contact

    set_conversation
    create_messages
    clear_message_source_id_from_redis
  end

  def process_statuses
    return unless find_message_by_source_id(@processed_params[:statuses].first[:id])

    update_message_with_status(@message, @processed_params[:statuses].first)
  rescue ArgumentError => e
    Rails.logger.error "Error while processing whatsapp status update #{e.message}"
  end

  def update_message_with_status(message, status)
    message.status = status[:status]
    if status[:status] == 'failed' && status[:errors].present?
      error = status[:errors]&.first
      message.external_error = "#{error[:code]}: #{error[:title]}"
    end
    message.save!
  end

  def create_messages
    message = @processed_params[:messages].first
    log_error(message) && return if error_webhook_event?(message)

    process_in_reply_to(message)

    message_type == 'contacts' ? create_contact_messages(message) : create_regular_message(message)
  end

  def create_message(message)
    @message = @conversation.messages.build(
      content: message_content(message),
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: message[:id].to_s,
      in_reply_to_external_id: @in_reply_to_external_id
    )
  end

  def create_contact_messages(message)
    message['contacts'].each do |contact|
      create_message(contact)
      attach_contact(contact)
      @message.save!
    end
  end

  def create_regular_message(message)
    create_message(message)
    attach_files
    attach_location if message_type == 'location'
    @message.save!
  end

  def set_contact
    contact_params = @processed_params[:contacts]&.first
    return if contact_params.blank?

    waid = processed_waid(contact_params[:wa_id])

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: waid,
      inbox: inbox,
      contact_attributes: { name: contact_params.dig(:profile, :name), phone_number: "+#{@processed_params[:messages].first[:from]}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    # if lock to single conversation is disabled, we will create a new conversation if previous conversation is resolved
    @conversation = if @inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations
                                    .where.not(status: :resolved).last
                    end

    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def attach_files
    return if %w[text button interactive location contacts].include?(message_type)

    attachment_payload = @processed_params[:messages].first[message_type.to_sym]
    @message.content ||= attachment_payload[:caption]

    attachment_file = download_attachment_file(attachment_payload)
    return if attachment_file.blank?

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  end

  def attach_location
    location = @processed_params[:messages].first['location']
    location_name = location['name'] ? "#{location['name']}, #{location['address']}" : ''
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      coordinates_lat: location['latitude'],
      coordinates_long: location['longitude'],
      fallback_title: location_name,
      external_url: location['url']
    )
  end

  def attach_contact(contact)
    phones = contact[:phones]
    phones = [{ phone: 'Phone number is not available' }] if phones.blank?

    phones.each do |phone|
      @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_content_type(message_type),
        fallback_title: phone[:phone].to_s
      )
    end
  end
end
