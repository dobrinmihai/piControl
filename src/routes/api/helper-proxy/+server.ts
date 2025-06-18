import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

function buildHelperUrl(ip: string, endpoint: string) {
    // Route authentication endpoints based on API documentation
    if (endpoint === '' || endpoint === 'auth') {
        // POST /auth for TOTP login
        return `http://${ip}:8220/auth`;
    } else if (endpoint === 'auth/status') {
        // GET /auth/status for auth status
        return `http://${ip}:8220/auth/status`;
    } else {
        // All other endpoints go to /api/*
        return `http://${ip}:8220/api/${endpoint}`;
    }
}

function filterHeaders(headers: Headers) {
    const result: Record<string, string> = {};
    for (const [key, value] of headers.entries()) {
        if (key.toLowerCase() !== 'cookie' && key.toLowerCase() !== 'host') {
            result[key] = value;
        }
    }
    return result;
}

export const GET: RequestHandler = async ({ url, request, locals }) => {
    // Check if user is authenticated
    if (!locals.pb || !locals.pb.authStore.isValid) {
        return json({ error: 'Unauthorized' }, { status: 401 });
    }
    const targetIp = url.searchParams.get('ip');
    const endpoint = url.searchParams.get('endpoint') || '';
    if (!targetIp) {
        return json({ error: 'IP address is required' }, { status: 400 });
    }
    let targetUrl = buildHelperUrl(targetIp, endpoint);
    // Copy all query params except 'ip' and 'endpoint'
    const queryParams = new URLSearchParams();
    for (const [key, value] of url.searchParams.entries()) {
        if (!['ip', 'endpoint'].includes(key)) {
            queryParams.append(key, value);
        }
    }
    const queryString = queryParams.toString();
    if (queryString) {
        targetUrl += `?${queryString}`;
    }
    try {
        const headers = filterHeaders(request.headers);
        const response = await fetch(targetUrl, { headers });
        if (!response.ok) {
            return json(
                { error: `Failed to execute request: ${response.statusText}` },
                { status: response.status }
            );
        }
        const data = await response.json();
        return json(data);
    } catch (error) {
        console.error(`Error with API request:`, error);
        return json({ error: `Failed to connect to helper service` }, { status: 500 });
    }
};

export const POST: RequestHandler = async ({ url, request, locals }) => {
    // Check if user is authenticated
    if (!locals.pb || !locals.pb.authStore.isValid) {
        return json({ error: 'Unauthorized' }, { status: 401 });
    }
    const targetIp = url.searchParams.get('ip');
    const endpoint = url.searchParams.get('endpoint') || '';
    if (!targetIp) {
        return json({ error: 'IP address is required' }, { status: 400 });
    }
    const targetUrl = buildHelperUrl(targetIp, endpoint);
    try {
        const headers = filterHeaders(request.headers);
        const requestBody = await request.text();
        const response = await fetch(targetUrl, {
            method: 'POST',
            headers,
            body: requestBody
        });
        if (!response.ok) {
            return json(
                { error: `Failed to execute request: ${response.statusText}` },
                { status: response.status }
            );
        }
        const data = await response.json();
        return json(data);
    } catch (error) {
        console.error(`Error with API request:`, error);
        return json({ error: `Failed to connect to helper service` }, { status: 500 });
    }
};