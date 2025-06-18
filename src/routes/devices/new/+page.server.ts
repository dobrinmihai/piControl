import type { PageServerLoad, Actions } from './$types';

// Function to perform the network scan using SvelteKit as a proxy
async function scanNetwork() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

    console.log('Initiating network scan via SvelteKit proxy endpoint');

    // Fetch directly from Go backend (server-side only)
    const response = await fetch('http://127.0.0.1:3000/scan', {
      method: 'GET',
      signal: controller.signal,
      headers: {
        'Accept': 'application/json'
      }
    });

    clearTimeout(timeoutId);

    console.log(`Response status: ${response.status}`);

    if (!response.ok) {
      console.error(`Error scanning network: ${response.status} ${response.statusText}`);
      return { networkDevices: [] };
    }

    const devices = await response.json();
    console.log('Raw response from Go service:', devices);

    // Map the response data to the expected format
    const networkDevices = devices.map((device: any) => ({
      mac_address: device.mac,
      ip_address: device.ip
    }));

    console.log(`Scan complete. Found ${networkDevices.length} devices.`);
    return { networkDevices };

  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      console.error('Network scan timed out after 30 seconds');
    } else {
      console.error('Error during network scan:', error);
    }
    return { networkDevices: [] };
  }
}

// Initial load function
export const load: PageServerLoad = async () => {
  console.log('🚀 PageServerLoad function called - starting network scan');
  const result = await scanNetwork();
  console.log('📊 Scan result:', result);
  return result;
};

// Action for rescanning
export const actions: Actions = {
  rescan: async () => {
    return scanNetwork();
  }
};