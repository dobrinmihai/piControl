import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

// Proxy GET for SSH WebSocket (upgrade)
export const GET: RequestHandler = async ({ request, url, locals }) => {
    // Only allow authenticated users
    if (!locals.pb || !locals.pb.authStore.isValid) {
        return new Response('Unauthorized', { status: 401 });
    }
    // SvelteKit does not natively proxy WebSocket upgrades, so this is a placeholder for future Node.js adapter/middleware
    return new Response('WebSocket proxy not implemented', { status: 501 });
};

// Proxy POST for SSH commands (if needed)
export const POST: RequestHandler = async ({ request, url, locals }) => {
    if (!locals.pb || !locals.pb.authStore.isValid) {
        return json({ error: 'Unauthorized' }, { status: 401 });
    }
    // Example: forward SSH command to Go API
    const body = await request.json();
    const response = await fetch('http://127.0.0.1:3000/ssh', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });
    const data = await response.json();
    return json(data);
};
