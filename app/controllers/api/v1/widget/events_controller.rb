require 'http'
class Api::V1::Widget::EventsController < Api::V1::Widget::BaseController
  include Events::Types
  include ChatbotHelper

  def create
    website_token = params[:website_token]
    Rails.configuration.dispatcher.dispatch(permitted_params[:name], Time.zone.now, contact_inbox: @contact_inbox,
                                                                                    event_info: permitted_params[:event_info].to_h.merge(event_info))
    head :no_content
    chatbot_ID = ChatbotHelper.get_chatbot_id(website_token)
    HTTP.post(
      ENV.fetch('MICROSERVICE_URL', nil) + '/cache-data',
      form: { chatbot_id: chatbot_ID },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
    )
  end

  private

  def event_info
    {
      widget_language: params[:locale],
      browser_language: browser.accept_language.first&.code,
      browser: browser_params
    }
  end

  def permitted_params
    params.permit(:name, :website_token, event_info: {})
  end
end
