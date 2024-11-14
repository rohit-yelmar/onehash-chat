require 'rails_helper'

RSpec.describe Webhooks::WhatsappEventsJob do
  subject(:job) { described_class }

  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:params)  do
    {
      object: 'whatsapp_business_account',
      phone_number: channel.phone_number,
      entry: [{
        changes: [
          {
            value: {
              metadata: {
                phone_number_id: channel.provider_config['phone_number_id'],
                display_phone_number: channel.phone_number.delete('+')
              }
            }
          }
        ]
      }]
    }
  end
  let(:process_service) { double }

  before do
    allow(process_service).to receive(:perform)
  end

  it 'enqueues the job' do
    expect { job.perform_later(params) }.to have_enqueued_job(described_class)
      .with(params)
      .on_queue('low')
  end

  context 'when whatsapp_cloud provider' do
    it 'enqueues Whatsapp::IncomingMessageWhatsappCloudService' do
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new).and_return(process_service)
      expect(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new)
      job.perform_now(params)
    end

    it 'will not enqueue message jobs based on phone number in the URL if the entry payload is not present' do
      params = {
        object: 'whatsapp_business_account',
        phone_number: channel.phone_number,
        entry: [{ changes: [{}] }]
      }
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new)
      allow(Whatsapp::IncomingMessageService).to receive(:new)

      expect(Whatsapp::IncomingMessageWhatsappCloudService).not_to receive(:new)
      expect(Whatsapp::IncomingMessageService).not_to receive(:new)
      job.perform_now(params)
    end

    it 'will not enqueue Whatsapp::IncomingMessageWhatsappCloudService if channel reauthorization required' do
      channel.prompt_reauthorization!
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new).and_return(process_service)
      expect(Whatsapp::IncomingMessageWhatsappCloudService).not_to receive(:new)
      job.perform_now(params)
    end

    it 'will not enqueue if channel is not present' do
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new).and_return(process_service)
      allow(Whatsapp::IncomingMessageService).to receive(:new).and_return(process_service)

      expect(Whatsapp::IncomingMessageWhatsappCloudService).not_to receive(:new)
      expect(Whatsapp::IncomingMessageService).not_to receive(:new)
      job.perform_now(phone_number: 'random_phone_number')
    end

    it 'will not enqueue Whatsapp::IncomingMessageWhatsappCloudService if account is suspended' do
      account = channel.account
      account.update!(status: :suspended)
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new).and_return(process_service)
      allow(Whatsapp::IncomingMessageService).to receive(:new).and.return(process_service)

      expect(Whatsapp::IncomingMessageWhatsappCloudService).not_to receive(:new)
      expect(Whatsapp::IncomingMessageService).not.to.receive(:new)
      job.perform_now(params)
    end
  end

  # New context for Gupshup provider with IncomingMessageGupshupService
  context 'when gupshup provider' do
    let(:channel) { create(:channel_whatsapp, provider: 'gupshup', sync_templates: false, validate_provider_config: false) }

    it 'enqueues Gupshup::IncomingMessageGupshupService' do
      allow(Gupshup::IncomingMessageGupshupService).to receive(:new).and.return(process_service)
      expect(Gupshup::IncomingMessageGupshupService).to receive(:new)
      job.perform_now(params)
    end

    it 'will not enqueue message jobs based on phone number in the URL if the entry payload is not present' do
      params = {
        object: 'whatsapp_business_account',
        phone_number: channel.phone_number,
        entry: [{ changes: [{}] }]
      }
      allow(Gupshup::IncomingMessageGupshupService).to receive(:new)
      allow(Whatsapp::IncomingMessageService).to receive(:new)

      expect(Gupshup::IncomingMessageGupshupService).not.to.receive(:new)
      expect(Whatsapp::IncomingMessageService).not.to.receive(:new)
      job.perform_now(params)
    end

    it 'will not enqueue Gupshup::IncomingMessageGupshupService if channel reauthorization required' do
      channel.prompt_reauthorization!
      allow(Gupshup::IncomingMessageGupshupService).to receive(:new).and.return(process_service)
      expect(Gupshup::IncomingMessageGupshupService).not.to.receive(:new)
      job.perform_now(params)
    end

    it 'will not enqueue if channel is not present' do
      allow(Gupshup::IncomingMessageGupshupService).to.receive(:new).and.return(process_service)
      allow(Whatsapp::IncomingMessageService).to receive(:new).and.return(process_service)

      expect(Gupshup::IncomingMessageGupshupService).not.to.receive(:new)
      expect(Whatsapp::IncomingMessageService).not.to.receive(:new)
      job.perform_now(phone_number: 'random_phone_number')
    end

    it 'will not enqueue Gupshup::IncomingMessageGupshupService if account is suspended' do
      account = channel.account
      account.update!(status: :suspended)
      allow(Gupshup::IncomingMessageGupshupService).to receive(:new).and.return(process_service)
      allow(Whatsapp::IncomingMessageService).to receive(:new).and.return(process_service)

      expect(Gupshup::IncomingMessageGupshupService).not.to.receive(:new)
      expect(Whatsapp::IncomingMessageService).not.to.receive(:new)
      job.perform_now(params)
    end
  end

  context 'when default provider' do
    it 'enqueues Whatsapp::IncomingMessageService' do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
      channel.update(provider: 'default')
      allow(Whatsapp::IncomingMessageService).to.receive(:new).and.return(process_service)
      expect(Whatsapp::IncomingMessageService).to receive(:new)
      job.perform_now(params)
    end
  end

  context 'when whatsapp business params' do
    it 'enqueues Whatsapp::IncomingMessageWhatsappCloudService based on the number in payload' do
      other_channel = create(:channel_whatsapp, phone_number: '+1987654', provider: 'whatsapp_cloud', sync_templates: false,
                                                validate_provider_config: false)
      wb_params = {
        phone_number: channel.phone_number,
        object: 'whatsapp_business_account',
        entry: [
          {
            changes: [
              {
                value: {
                  metadata: {
                    phone_number_id: other_channel.provider_config['phone_number_id'],
                    display_phone_number: other_channel.phone_number.delete('+')
                  }
                }
              }
            ]
          }
        ]
      }
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to.receive(:new).and.return(process_service)
      expect(Whatsapp::IncomingMessageWhatsappCloudService).to.receive(:new).with(inbox: other_channel.inbox, params: wb_params)
      job.perform_now(wb_params)
    end

    it 'ignores reaction type message and stops raising error' do
      other_channel = create(:channel_whatsapp, phone_number: '+1987654', provider: 'whatsapp_cloud', sync_templates: false,
                                                validate_provider_config: false)
      wb_params = {
        phone_number: channel.phone_number,
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              contacts: [{ profile: { name: 'Test Test' }, wa_id: '1111981136571' }],
              messages: [{
                from: '1111981136571', reaction: { emoji: '👍' }, timestamp: '1664799904', type: 'reaction'
              }],
              metadata: {
                phone_number_id: other_channel.provider_config['phone_number_id'],
                display_phone_number: other_channel.phone_number.delete('+')
              }
            }
          }]
        }]
      }.with_indifferent_access
      expect do
        Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: other_channel.inbox, params: wb_params).perform
      end.not to.change(Message, :count)
    end

    it 'will not enqueue Whatsapp::IncomingMessageWhatsappCloudService when invalid phone number id' do
      other_channel = create(:channel_whatsapp, phone_number: '+1987654', provider: 'whatsapp_cloud', sync_templates: false,
                                                validate_provider_config: false)
      wb_params = {
        phone_number: channel.phone_number,
        object: 'whatsapp_business_account',
        entry: [
          {
            changes: [
              {
                value: {
                  metadata: {
                    phone_number_id: 'random phone number id',
                    display_phone_number: other_channel.phone_number.delete('+')
                  }
                }
              }
            ]
          }
        ]
      }
      allow(Whatsapp::IncomingMessageWhatsappCloudService).to receive(:new).and.return(process_service)
      expect(Whatsapp::IncomingMessageWhatsappCloudService).not.to.receive(:new).with(inbox: other_channel.inbox, params: wb_params)
      job.perform_now(wb_params)
    end
  end
end
