import PocketBase from 'pocketbase';
import { browser } from '$app/environment';

// Create a single PocketBase instance to use throughout your app
export const pb = new PocketBase("http://localhost:8090");

// Configure auth store persistence for browser
if (browser) {
    // Load auth from cookie on browser
    pb.authStore.loadFromCookie(document.cookie);
    
    // Save auth changes to cookie and handle clearing
    pb.authStore.onChange(() => {
        if (pb.authStore.isValid) {
            document.cookie = pb.authStore.exportToCookie({ httpOnly: false });
        } else {
            // Clear all auth-related cookies
            document.cookie = 'pb_auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; SameSite=Lax;';
            document.cookie = 'pb_auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; Domain=localhost; SameSite=Lax;';
            document.cookie = 'pb_auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; Domain=127.0.0.1; SameSite=Lax;';
        }
    });
    
    // Auto-refresh auth token before it expires
    setInterval(async () => {
        if (pb.authStore.isValid) {
            try {
                await pb.collection('users').authRefresh();
            } catch (error) {
                console.error('Failed to refresh auth token:', error);
                // If refresh fails, clear the auth store
                pb.authStore.clear();
            }
        }
    }, 4 * 60 * 1000); // Refresh every 4 minutes (tokens typically last 15 minutes)
}