import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ fetch, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return { devices: [] };
        }

        // Fetch devices via API endpoint (which handles authentication)
        const response = await fetch('/api/devices');
        if (!response.ok) {
            console.error('Error fetching devices:', response.statusText);
            return { devices: [] };
        }

        const data = await response.json();
        return { devices: data.devices };
    } catch (error) {
        console.error('Error fetching devices:', error);
        return { devices: [] };
    }
};