# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join 'spec/models/concerns/reauthorizable_shared.rb'

RSpec.describe Channel::Whatsapp do
  describe 'concerns' do
    let(:channel) { create(:channel_whatsapp) }

    before do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
      stub_request(:get, 'https://waba.360dialog.io/v1/configs/templates')
    end

    it_behaves_like 'reauthorizable'

    context 'when prompt_reauthorization!' do
      it 'calls channel notifier mail for whatsapp' do
        admin_mailer = double
        mailer_double = double

        expect(AdministratorNotifications::ChannelNotificationsMailer).to receive(:with).and_return(admin_mailer)
        expect(admin_mailer).to receive(:whatsapp_disconnect).with(channel.inbox).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_later)

        channel.prompt_reauthorization!
      end
    end
  end

  describe 'validate_provider_config' do
    let(:channel_whatsapp_cloud) { build(:channel_whatsapp, provider: 'whatsapp_cloud', account: create(:account)) }
    let(:channel_gupshup) { build(:channel_whatsapp, provider: 'gupshup', account: create(:account)) }

    it 'validates false when provider config is wrong for whatsapp_cloud' do
      stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key').to_return(status: 401)
      expect(channel_whatsapp_cloud.save).to be(false)
    end

    it 'validates true when provider config is right for whatsapp_cloud' do
      stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key')
        .to_return(status: 200,
                   body: { data: [{
                     id: '123456789', name: 'test_template'
                   }] }.to_json)
      expect(channel_whatsapp_cloud.save).to be(true)
    end

    it 'validates false when provider config is wrong for gupshup' do
      stub_request(:get, 'https://api.gupshup.io/sm/api/v1/template/list?apikey=test_key').to_return(status: 401)
      expect(channel_gupshup.save).to be(false)
    end

    it 'validates true when provider config is right for gupshup' do
      stub_request(:get, 'https://api.gupshup.io/sm/api/v1/template/list?apikey=test_key')
        .to_return(status: 200,
                   body: { templates: [{
                     id: '123456789', name: 'gupshup_template'
                   }] }.to_json)
      expect(channel_gupshup.save).to be(true)
    end
  end

  describe 'webhook_verify_token' do
    it 'generates webhook_verify_token if not present for whatsapp_cloud' do
      channel = create(:channel_whatsapp, provider_config: { webhook_verify_token: nil }, provider: 'whatsapp_cloud', account: create(:account),
                                          validate_provider_config: false, sync_templates: false)

      expect(channel.provider_config['webhook_verify_token']).not_to be_nil
    end

    it 'does not generate webhook_verify_token if present for whatsapp_cloud' do
      channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', provider_config: { webhook_verify_token: '123' }, account: create(:account),
                                          validate_provider_config: false, sync_templates: false)

      expect(channel.provider_config['webhook_verify_token']).to eq '123'
    end

    it 'generates webhook_verify_token if not present for gupshup' do
      channel = create(:channel_whatsapp, provider_config: { webhook_verify_token: nil }, provider: 'gupshup', account: create(:account),
                                          validate_provider_config: false, sync_templates: false)

      expect(channel.provider_config['webhook_verify_token']).not_to be_nil
    end

    it 'does not generate webhook_verify_token if present for gupshup' do
      channel = create(:channel_whatsapp, provider: 'gupshup', provider_config: { webhook_verify_token: 'gupshup_token' }, account: create(:account),
                                          validate_provider_config: false, sync_templates: false)

      expect(channel.provider_config['webhook_verify_token']).to eq 'gupshup_token'
    end
  end
end
