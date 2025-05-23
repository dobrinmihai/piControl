import type { PageServerLoad, Actions } from './$types';

// Function to perform the network scan using HTTP endpoint
async function scanNetwork() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout
    
    console.log('Initiating network scan via HTTP endpoint');
    
    const response = await fetch('http://127.0.0.1:3000/scan', {
      method: 'GET',
      signal: controller.signal,
      headers: {
        'Accept': 'application/json'
      }
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      console.error(`Error scanning network: ${response.status} ${response.statusText}`);
      return { networkDevices: [] };
    }
    
    const devices = await response.json();
    
    // Map the response data to the expected format
    const networkDevices = devices.map((device: any) => ({
      mac_address: device.mac,
      ip_address: device.ip
    }));
    
    console.log(`Scan complete. Found ${networkDevices.length} devices.`);
    return { networkDevices };
    
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      console.error('Network scan timed out after 10 seconds');
    } else {
      console.error('Error during network scan:', error);
    }
    return { networkDevices: [] };
  }
}

// Initial load function
export const load: PageServerLoad = async () => {
  return scanNetwork();
};

// Action for rescanning
export const actions: Actions = {
  rescan: async () => {
    return scanNetwork();
  }
};