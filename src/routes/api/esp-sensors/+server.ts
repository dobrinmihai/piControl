import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, locals }) => {
    // Check if user is authenticated
    if (!locals.pb || !locals.pb.authStore.isValid) {
        return json({ error: 'Unauthorized' }, { status: 401 });
    }

    const targetIp = url.searchParams.get('ip');
    if (!targetIp) {
        return json({ error: 'IP address is required' }, { status: 400 });
    }
    
    try {
        const response = await fetch(`http://${targetIp}:8321/sensors`);
        if (!response.ok) {
            return json({ error: `Failed to fetch sensors: ${response.statusText}` }, { status: response.status });
        }
        const data = await response.json();
        return json(data);
    } catch (error) {
        console.error('Error fetching sensors:', error);
        return json({ error: 'Failed to connect to ESP32 sensors' }, { status: 500 });
    }
};