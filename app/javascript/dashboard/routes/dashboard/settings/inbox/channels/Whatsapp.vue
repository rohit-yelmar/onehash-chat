<script>
import PageHeader from '../../SettingsSubPageHeader.vue';
import Twilio from './Twilio.vue';
import ThreeSixtyDialogWhatsapp from './360DialogWhatsapp.vue';
import CloudWhatsapp from './CloudWhatsapp.vue';
import GupshupWhatsapp from './GupshupWhatsapp.vue'; // Import the new Gupshup component

export default {
  components: {
    PageHeader,
    Twilio,
    ThreeSixtyDialogWhatsapp,
    CloudWhatsapp,
    GupshupWhatsapp, // Register the new Gupshup component
  },
  data() {
    return {
      provider: 'whatsapp_cloud', // Default provider remains the same
    };
  },
};
</script>

<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.WHATSAPP.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.WHATSAPP.DESC')"
    />
    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
      <label>
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.LABEL') }}
        <select v-model="provider">
          <option value="whatsapp_cloud">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD') }}
          </option>
          <option value="twilio">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO') }}
          </option>
          <option value="gupshup">
            <!-- Add Gupshup option -->
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.GUPSHUP') }}
          </option>
        </select>
      </label>
    </div>

    <Twilio v-if="provider === 'twilio'" type="whatsapp" />
    <ThreeSixtyDialogWhatsapp v-else-if="provider === '360dialog'" />
    <CloudWhatsapp v-else-if="provider === 'whatsapp_cloud'" />
    <GupshupWhatsapp v-else />
    <!-- Render Gupshup component when selected -->
  </div>
</template>
