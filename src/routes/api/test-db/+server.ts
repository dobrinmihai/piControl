import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ locals }) => {
    try {
        // Check if user is authenticated
        if (!locals.pb || !locals.pb.authStore.isValid) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        // Try to list all collections first
        try {
            const collections = await locals.pb.collections.getFullList();
            console.log('Available collections:', collections.map(c => c.name));
            
            // Try to get a simple health check from devices collection
            const healthCheck = await locals.pb.collection('devices').getList(1, 1);
            
            return json({ 
                success: true, 
                collections: collections.map(c => c.name),
                devicesCount: healthCheck.totalItems,
                sampleDevices: healthCheck.items
            });
        } catch (error) {
            console.error('Database error:', error);
            return json({ 
                error: 'Database error',
                details: error instanceof Error ? error.message : 'Unknown error'
            }, { status: 500 });
        }
    } catch (error) {
        console.error('Test DB error:', error);
        return json({ 
            error: error instanceof Error ? error.message : 'Failed to test database' 
        }, { status: 500 });
    }
};
