import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, locals }) => {
    // Check if user is authenticated
    if (!locals.pb || !locals.pb.authStore.isValid) {
        return json({ error: 'Unauthorized' }, { status: 401 });
    }

    const targetIp = url.searchParams.get('ip');
    if (!targetIp) {
        return json({ error: 'IP address is required' }, { status: 400 });
    }
    
    try {
        // Set a shorter timeout for ESP32 devices (they should respond quickly if online)
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 3000); // 3 second timeout
        
        const response = await fetch(`http://${targetIp}:8321/status`, {
            signal: controller.signal,
            headers: {
                'Content-Type': 'application/json',
            }
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok) {
            return json({ 
                status: "offline", 
                error: `ESP32 returned ${response.status}: ${response.statusText}` 
            }, { status: 200 }); // Return 200 but mark device as offline
        }
        
        const data = await response.json();
        
        // Normalize the response
        let normalized = data;
        if (data.online === true || data.status === "online" || data.status === "running") {
            normalized = { status: "running" };
        } else if (data.online === false || data.status === "offline" || data.status === "stopped") {
            normalized = { status: "stopped" };
        } else {
            // Default to running if we got a response
            normalized = { status: "running" };
        }
        
        return json(normalized);
    } catch (error: any) {
        console.error(`Error fetching ESP32 status from ${targetIp}:`, error.message);
        
        // If it's a timeout or connection error, the device is likely offline
        if (error.name === 'AbortError' || error.code === 'UND_ERR_CONNECT_TIMEOUT' || error.cause?.code === 'UND_ERR_CONNECT_TIMEOUT') {
            return json({ status: "offline", error: "Device unreachable" }, { status: 200 });
        }
        
        // For other errors, still mark as offline but log the specific error
        return json({ 
            status: "offline", 
            error: `Connection failed: ${error.message}` 
        }, { status: 200 });
    }
};