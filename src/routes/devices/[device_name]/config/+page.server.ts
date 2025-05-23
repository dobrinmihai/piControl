import { pb } from '$lib/pocketbase.js';
import { error } from '@sveltejs/kit';

export async function load({ params }: any ) {
    try {
        // Get the device_name from the URL parameter
        const device_name = params.device_name;
        
        // Fetch the device from PocketBase
        const device = await pb.collection('devices').getFirstListItem(`device_name="${device_name}"`);
        
        return {
            device,
            device_name
        };
    } catch (err) {
        console.error('Error loading device:', err);
        throw error(404, 'Device not found');
    }
}