import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            throw error(401, 'Unauthorized');
        }

        // Get the device_name from the URL parameter
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
            try {
                // Fall back to name-only filter
                device = await locals.pb.collection('devices').getFirstListItem(
                    `device_name="${device_name}"`
                );
            } catch (nameError) {
                console.error('Device not found:', nameError);
                throw error(404, 'Device not found');
            }
        }
        
        console.log('Device loaded:', device);
        return {
            device,
            device_name
        };
    } catch (err) {
        console.error('Error loading device:', err);
        throw error(404, 'Device not found');
    }
};