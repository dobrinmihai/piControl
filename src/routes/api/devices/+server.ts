import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';

export const POST: RequestHandler = async ({ request, locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        const body = await request.json();
        const { device_name, mac_addr, ip_addr, type } = body;

        // Validate required fields
        if (!device_name || !mac_addr || !ip_addr || !type) {
            return json({ error: 'Missing required fields' }, { status: 400 });
        }

        // Create device in PocketBase with authenticated user
        const deviceData: any = {
            device_name,
            mac_addr,
            ip_addr,
            type, // always store as 'type'
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
        if (!locals.pb || !locals.pb.authStore.isValid || !locals.user) {
            console.log('Authentication check failed:', {
                hasLb: !!locals.pb,
                isValid: locals.pb?.authStore.isValid,
                hasUser: !!locals.user
            });
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        console.log(`Fetching devices for user: ${locals.user.id}`);

        // Try different approaches in order of likelihood
        let devices = [];
        let lastError: any = null;

        // Approach 1: Try with owner filter (most likely scenario)
        try {
            devices = await locals.pb.collection('devices').getFullList({
                filter: `owner = "${locals.user.id}"`,
                sort: '-created',
            });
            console.log(`✓ Found ${devices.length} devices (with owner filter)`);
            return json({ devices });
        } catch (error: any) {
            console.log('❌ Owner filter failed:', error?.message || error);
            lastError = error;
        }

        // Approach 2: Try without filter (if no API rules)
        try {
            devices = await locals.pb.collection('devices').getFullList({
                sort: '-created',
            });
            console.log(`✓ Found ${devices.length} devices (no filter)`);
            return json({ devices });
        } catch (error: any) {
            console.log('❌ No filter failed:', error?.message || error);
            lastError = error;
        }

        // Approach 3: Try simple request without sort
        try {
            devices = await locals.pb.collection('devices').getFullList();
            console.log(`✓ Found ${devices.length} devices (basic)`);
            return json({ devices });
        } catch (error: any) {
            console.log('❌ Basic request failed:', error?.message || error);
            lastError = error;
        }

        // If all approaches fail, return empty with error info
        console.error('All approaches failed. Last error:', lastError);
        return json({ 
            devices: [], 
            error: `Unable to fetch devices: ${lastError?.message || 'Unknown error'}`,
            debug: {
                userId: locals.user.id,
                authValid: locals.pb.authStore.isValid,
                lastError: lastError?.message || lastError
            }
        });
    } catch (error: any) {
        console.error('Error in devices API:', error);
        return json({ 
            error: error?.message || 'Failed to fetch devices' 
        }, { status: 500 });
    }
};
