import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, request }) => {
    const targetIp = url.searchParams.get('ip');
    const endpoint = url.searchParams.get('endpoint');
    
    if (!targetIp || !endpoint) {
        return json({ error: 'IP address and endpoint are required' }, { status: 400 });
    }
    
    // Build the full URL, preserving any additional query params
    let targetUrl = `http://${targetIp}:8220/${endpoint}`;
    
    // Copy all query params except 'ip' and 'endpoint'
    const queryParams = new URLSearchParams();
    for (const [key, value] of url.searchParams.entries()) {
        if (key !== 'ip' && key !== 'endpoint') {
            queryParams.append(key, value);
        }
    }
    
    // Append query params if any exist
    const queryString = queryParams.toString();
    if (queryString) {
        targetUrl += `?${queryString}`;
    }
    
    try {
        const response = await fetch(targetUrl);
        
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

export const POST: RequestHandler = async ({ url, request }) => {
    const targetIp = url.searchParams.get('ip');
    const endpoint = url.searchParams.get('endpoint');
    
    if (!targetIp || !endpoint) {
        return json({ error: 'IP address and endpoint are required' }, { status: 400 });
    }
    
    try {
        // Build the target URL
        const targetUrl = `http://${targetIp}:8220/${endpoint}`;
        
        // Forward the request body
        const requestBody = await request.json();
        
        const response = await fetch(targetUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
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