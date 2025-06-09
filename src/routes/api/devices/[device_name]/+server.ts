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
