import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ params, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        const device_name = params.device_name;

        // Try to fetch the device with owner filter first, fall back to name-only filter
        let device;
        try {
            // Try with owner filter
            device = await locals.pb.collection('devices').getFirstListItem(
                `device_name="${device_name}" && owner="${locals.user?.id}"`
            );
        } catch (ownerError) {
            console.warn('Owner field not found, trying without owner filter:', ownerError);
            // Fall back to name-only filter
            device = await locals.pb.collection('devices').getFirstListItem(
                `device_name="${device_name}"`
            );
        }

        return json({ device });
    } catch (error) {
        console.error('Error fetching device:', error);
        return json({ 
            error: error instanceof Error ? error.message : 'Device not found' 
        }, { status: 404 });
    }
};

export const PUT: RequestHandler = async ({ params, request, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        const device_name = params.device_name;
        const body = await request.json();
        const { device_name: new_device_name, mac_addr, ip_addr, type } = body;

        // Validate required fields
        if (!new_device_name || !mac_addr || !ip_addr || !type) {
            return json({ error: 'Missing required fields' }, { status: 400 });
        }

        // First, find the device to get its ID
        let device;
        try {
            // Try with owner filter
            device = await locals.pb.collection('devices').getFirstListItem(
                `device_name="${device_name}" && owner="${locals.user?.id}"`
            );
        } catch (ownerError) {
            console.warn('Owner field not found, trying without owner filter:', ownerError);
            // Fall back to name-only filter
            device = await locals.pb.collection('devices').getFirstListItem(
                `device_name="${device_name}"`
            );
        }

        // Update the device
        const updatedDevice = await locals.pb.collection('devices').update(device.id, {
            device_name: new_device_name,
            mac_addr,
            ip_addr,
            type
        });

        return json({ success: true, device: updatedDevice });
    } catch (error) {
        console.error('Error updating device:', error);
        return json({ 
            error: error instanceof Error ? error.message : 'Failed to update device' 
        }, { status: 500 });
    }
};

export const DELETE: RequestHandler = async ({ params, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        const device_name = params.device_name;

        // First, find the device to get its ID
        let device;
        try {
            // Try with owner filter
            device = await locals.pb.collection('devices').getFirstListItem(
                `device_name="${device_name}" && owner="${locals.user?.id}"`
            );
        } catch (ownerError) {
            console.warn('Owner field not found, trying without owner filter:', ownerError);
            // Fall back to name-only filter
            device = await locals.pb.collection('devices').getFirstListItem(
                `device_name="${device_name}"`
            );
        }

        // Delete the device
        await locals.pb.collection('devices').delete(device.id);

        return json({ success: true });
    } catch (error) {
        console.error('Error deleting device:', error);
        return json({ 
            error: error instanceof Error ? error.message : 'Failed to delete device' 
        }, { status: 500 });
    }
};
