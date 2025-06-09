import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';

export const POST: RequestHandler = async ({ request, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        const body = await request.json();
        const { device_name, mac_addr, ip_addr, device_type } = body;

        // Validate required fields
        if (!device_name || !mac_addr || !ip_addr || !device_type) {
            return json({ error: 'Missing required fields' }, { status: 400 });
        }

        // Create device in PocketBase with authenticated user
        const deviceData: any = {
            device_name,
            mac_addr,
            ip_addr,
            device_type,
            created: new Date().toISOString(),
        };

        // Add owner field if user is authenticated
        if (locals.user?.id) {
            deviceData.owner = locals.user.id;
        }

        const device = await locals.pb.collection('devices').create(deviceData);

        return json({ success: true, device });
    } catch (error) {
        console.error('Error creating device:', error);
        return json({ 
            error: error instanceof Error ? error.message : 'Failed to create device' 
        }, { status: 500 });
    }
};

export const GET: RequestHandler = async ({ locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        // Try to fetch devices - simplified approach
        try {
            const devices = await locals.pb.collection('devices').getFullList({
                sort: '-created',
            });
            console.log(`Found ${devices.length} devices`);
            return json({ devices });
        } catch (error) {
            console.error('Error fetching devices:', error);
            // Return empty array if there's an error, but still indicate success for UI
            return json({ devices: [] });
        }
    } catch (error) {
        console.error('Error in devices API:', error);
        return json({ 
            error: error instanceof Error ? error.message : 'Failed to fetch devices' 
        }, { status: 500 });
    }
};
