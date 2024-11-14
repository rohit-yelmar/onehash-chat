require 'rails_helper'

RSpec.describe Whatsapp::Providers::GupshupService do
  let(:whatsapp_channel) { create(:channel_whatsapp) }
  let(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }
  let(:phone_number) { '+1234567890' }
  let(:api_key) { whatsapp_channel.provider_config['api_key'] }
  let(:source) { whatsapp_channel.provider_config['source'] }
  let(:message) { create(:message, content: 'Hello World', message_type: :outgoing) }

  describe '#send_message' do
    context 'when sending a text message' do
      it 'sends a text message to the correct Gupshup API endpoint' do
        stub_request(:post, 'https://api.gupshup.io/wa/api/v1/msg')
          .with(
            headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'apikey' => api_key },
            body: hash_including({
                                   channel: 'whatsapp',
                                   source: source,
                                   destination: phone_number,
                                   message: { type: 'text', text: 'Hello World' }.to_json
                                 })
          )
          .to_return(status: 200, body: { messageId: '123' }.to_json)

        service.send_message(phone_number, message)
      end
    end

    context 'when sending an attachment message' do
      let(:attachment) { create(:attachment, file_type: 'image', download_url: 'https://example.com/image.jpg') }
      let(:message_with_attachment) { create(:message, attachments: [attachment], content: 'Check this image') }

      it 'sends an image attachment message to the correct Gupshup API endpoint' do
        stub_request(:post, 'https://api.gupshup.io/wa/api/v1/msg')
          .with(
            headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'apikey' => api_key },
            body: hash_including({
                                   channel: 'whatsapp',
                                   source: source,
                                   destination: phone_number,
                                   message: {
                                     type: 'image',
                                     originalUrl: 'https://example.com/image.jpg',
                                     previewUrl: 'https://example.com/image.jpg',
                                     caption: 'Check this image'
                                   }.to_json
                                 })
          )
          .to_return(status: 200, body: { messageId: '456' }.to_json)

        service.send_message(phone_number, message_with_attachment)
      end
    end

    context 'when sending an interactive message' do
      let(:interactive_message) { create(:message, content_type: 'input_select', content: 'Choose an option') }

      it 'sends an interactive message to the correct Gupshup API endpoint' do
        stub_request(:post, 'https://api.gupshup.io/wa/api/v1/msg')
          .with(
            headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'apikey' => api_key },
            body: hash_including({
                                   channel: 'whatsapp',
                                   source: source,
                                   destination: phone_number,
                                   message: {
                                     type: 'interactive',
                                     interactive: an_instance_of(Hash) # Adjust as per your payload structure
                                   }.to_json
                                 })
          )
          .to_return(status: 200, body: { messageId: '789' }.to_json)

        service.send_message(phone_number, interactive_message)
      end
    end
  end

  describe '#sync_templates' do
    let(:app_id) { whatsapp_channel.provider_config['app_id'] }

    it 'syncs templates from the correct Gupshup API endpoint' do
      stub_request(:get, "https://api.gupshup.io/wa/app/#{app_id}/template")
        .with(
          headers: { 'accept' => 'application/json', 'apikey' => api_key }
        )
        .to_return(status: 200, body: { templates: [{ name: 'Template1' }] }.to_json)

      expect(whatsapp_channel).to receive(:update).with(templates: [{ name: 'Template1' }])
      expect(whatsapp_channel).to receive(:mark_message_templates_updated)

      service.sync_templates
    end

    it 'handles failure to sync templates' do
      stub_request(:get, "https://api.gupshup.io/wa/app/#{app_id}/template")
        .with(
          headers: { 'accept' => 'application/json', 'apikey' => api_key }
        )
        .to_return(status: 500, body: 'Internal Server Error')

      expect(Rails.logger).to receive(:error).with('Failed to sync templates: Internal Server Error')

      service.sync_templates
    end
  end

  describe '#send_text_message' do
    it 'sends a text message correctly' do
      stub_request(:post, 'https://api.gupshup.io/wa/api/v1/msg')
        .with(
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'apikey' => api_key },
          body: hash_including({
                                 channel: 'whatsapp',
                                 source: source,
                                 destination: phone_number,
                                 message: { type: 'text', text: 'Hello World' }.to_json
                               })
        )
        .to_return(status: 200, body: { messageId: '123' }.to_json)

      expect(service.send_text_message(phone_number, message)).to eq('123')
    end

    it 'logs an error if sending a message fails' do
      stub_request(:post, 'https://api.gupshup.io/wa/api/v1/msg')
        .with(
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'apikey' => api_key }
        )
        .to_return(status: 500, body: 'Internal Server Error')

      expect(Rails.logger).to receive(:error).with('Internal Server Error')

      service.send_text_message(phone_number, message)
    end
  end

  describe '#send_attachment_message' do
    let(:attachment) { create(:attachment, file_type: 'image', download_url: 'https://example.com/image.jpg') }
    let(:message_with_attachment) { create(:message, attachments: [attachment], content: 'Check this image') }

    it 'sends an attachment message correctly' do
      stub_request(:post, 'https://api.gupshup.io/wa/api/v1/msg')
        .with(
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'apikey' => api_key },
          body: hash_including({
                                 channel: 'whatsapp',
                                 source: source,
                                 destination: phone_number,
                                 message: {
                                   type: 'image',
                                   originalUrl: 'https://example.com/image.jpg',
                                   previewUrl: 'https://example.com/image.jpg',
                                   caption: 'Check this image'
                                 }.to_json
                               })
        )
        .to_return(status: 200, body: { messageId: '456' }.to_json)

      expect(service.send_attachment_message(phone_number, message_with_attachment)).to eq('456')
    end
  end
end
