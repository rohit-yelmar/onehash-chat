require 'http'
class Api::V1::Widget::MessagesController < Api::V1::Widget::BaseController
  before_action :set_conversation, only: [:create]
  before_action :set_message, only: [:update]

  def index
    @messages = conversation.nil? ? [] : message_finder.perform
  end

  def create
    website_token = params[:website_token]
    chatbot = Chatbot.find_by(website_token: website_token)
    if chatbot && chatbot.status == 'Enabled'
      id = chatbot.id
      conversation_id = conversation.id
      conversation = Conversation.find_by(id: conversation_id)
      @message = conversation.messages.new(message_params)
      client_message = @message[:content]
      @message.save!
      if conversation.present?
        trigger_chatbot_typing_status(conversation_id, true)
        res = HTTP.post(
          ENV.fetch('MICROSERVICE_URL', nil) + '/chatbot/query',
          form: { id: id, user_query: client_message },
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
        )
  
        bot_message = JSON.parse(res.body)['result']
        email_collect = MessageTemplates::Template::EmailCollect.new(conversation: @conversation)
        email_collect.chatbot(bot_message)
        trigger_chatbot_typing_status(conversation_id, false)
      end
    else
      @message = conversation.messages.new(message_params)
      build_attachment
      @message.save!
    end 
  end

  def update
    if @message.content_type == 'input_email'
      @message.update!(submitted_email: contact_email)
      ContactIdentifyAction.new(
        contact: @contact,
        params: { email: contact_email, name: contact_name },
        retain_original_contact_name: true
      ).perform
    else
      @message.update!(message_update_params[:message])
    end
  rescue StandardError => e
    render json: { error: @contact.errors, message: e.message }.to_json, status: :internal_server_error
  end

  private

  def build_attachment
    return if params[:message][:attachments].blank?

    params[:message][:attachments].each do |uploaded_attachment|
      attachment = @message.attachments.new(
        account_id: @message.account_id,
        file: uploaded_attachment
      )

      attachment.file_type = helpers.file_type(uploaded_attachment&.content_type) if uploaded_attachment.is_a?(ActionDispatch::Http::UploadedFile)
    end
  end

  def set_conversation
    @conversation = create_conversation if conversation.nil?
  end

  def message_finder_params
    {
      filter_internal_messages: true,
      before: permitted_params[:before],
      after: permitted_params[:after]
    }
  end

  def message_finder
    @message_finder ||= MessageFinder.new(conversation, message_finder_params)
  end

  def message_update_params
    params.permit(message: [{ submitted_values: [:name, :title, :value, { csat_survey_response: [:feedback_message, :rating] }] }])
  end

  def permitted_params
    # timestamp parameter is used in create conversation method
    params.permit(:id, :before, :after, :website_token, contact: [:name, :email], message: [:content, :referer_url, :timestamp, :echo_id, :reply_to])
  end

  def set_message
    @message = @web_widget.inbox.messages.find(permitted_params[:id])
  end

  def trigger_chatbot_typing_status(conversation_id, typing_status)
    # Fetch the conversation object based on the conversation_id
    @conversation = Conversation.find(conversation_id)
    # Get the current_user object (or an appropriate user object)
    @current_user = @conversation.assignee
    params = {
      typing_status: typing_status ? 'on' : 'off',
      is_private: false
    }
    typing_status_manager = ::Conversations::TypingStatusManager.new(@conversation,@current_user,params) 
    typing_status_manager.toggle_typing_status
  end
end
