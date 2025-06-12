import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ locals }) => {
    try {
        console.log('=== Test devices endpoint ===');
        
        if (!locals.pb || !locals.pb.authStore.isValid || !locals.user) {
            console.log('Authentication failed');
            return json({ 
                error: 'Unauthorized',
                auth: {
                    hasPb: !!locals.pb,
                    isValid: locals.pb?.authStore.isValid,
                    hasUser: !!locals.user
                }
            }, { status: 401 });
        }

        console.log('User authenticated:', locals.user.id);

        // Try basic fetch first
        const devices = await locals.pb.collection('devices').getFullList({
            sort: '-created',
        });
        
        console.log(`Found ${devices.length} total devices`);
        
        const esp32Devices_type = devices.filter(d => d.type === 'esp32');
        const esp32Devices_device_type = devices.filter(d => d.device_type === 'esp32');
        console.log(`Found ${esp32Devices_type.length} ESP32 devices using 'type' field`);
        console.log(`Found ${esp32Devices_device_type.length} ESP32 devices using 'device_type' field`);
        
        return json({ 
            success: true,
            totalDevices: devices.length,
            esp32_using_type: esp32Devices_type.length,
            esp32_using_device_type: esp32Devices_device_type.length,
            devices: devices.map(d => ({
                id: d.id,
                name: d.device_name,
                type: d.type,
                device_type: d.device_type,
                ip: d.ip_addr
            }))
        });
    } catch (error: any) {
        console.error('Test devices error:', error);
        return json({ 
            error: error.message,
            details: error.toString()
        }, { status: 500 });
    }
};
