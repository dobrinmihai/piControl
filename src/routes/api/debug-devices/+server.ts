import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ locals }) => {
    try {
        if (!locals.pb || !locals.pb.authStore.isValid || !locals.user) {
            return json({ error: 'Unauthorized' }, { status: 401 });
        }

        const debug: any = {
            user: {
                id: locals.user.id,
                email: locals.user.email
            },
            auth: {
                isValid: locals.pb.authStore.isValid,
                token: locals.pb.authStore.token ? 'present' : 'missing'
            }
        };

        // Try to get collection info
        try {
            const collections = await locals.pb.collections.getFullList();
            const devicesCollection = collections.find(c => c.name === 'devices');
            
            debug.collection = {
                exists: !!devicesCollection,
                schema: devicesCollection?.schema || 'not found'
            };
        } catch (error: any) {
            debug.collectionError = error?.message || 'Unknown error';
        }

        // Try direct API call to see raw response
        try {
            const response = await fetch(`http://localhost:8090/api/collections/devices/records`, {
                headers: {
                    'Authorization': `Bearer ${locals.pb.authStore.token}`
                }
            });
            
            const rawData = await response.text();
            debug.directAPI = {
                status: response.status,
                statusText: response.statusText,
                headers: Object.fromEntries(response.headers.entries()),
                body: rawData.substring(0, 500) // First 500 chars
            };
        } catch (error: any) {
            debug.directAPIError = error?.message || 'Unknown error';
        }

        return json({ debug });
    } catch (error: any) {
        return json({ 
            error: error?.message || 'Unknown error',
            stack: error?.stack || 'No stack trace'
        }, { status: 500 });
    }
};
