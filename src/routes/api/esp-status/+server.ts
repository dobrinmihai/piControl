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
        const response = await fetch(`http://${targetIp}:8321/status`);
        if (!response.ok) {
            return json({ error: `Failed to fetch ESP32 status: ${response.statusText}` }, { status: response.status });
        }
        const data = await response.json();
        // Normalize if needed
        let normalized = data;
        if (data.online === true || data.status === "online") {
            normalized = { status: "running" };
        } else if (data.online === false || data.status === "offline") {
            normalized = { status: "stopped" };
        }
        return json(normalized);
    } catch (error) {
        console.error('Error fetching ESP32 status:', error);
        return json({ error: 'Failed to connect to ESP32 status' }, { status: 500 });
    }
};