import { writable } from 'svelte/store';
import { pb } from '$lib/pocketbase';

// PocketBase Auth Store
export const user = writable(pb.authStore.record);

// Listen for auth changes
pb.authStore.onChange(() => {
    user.set(pb.authStore.record);
});

// Auth Functions
export async function login(email: string, password: string) {
    await pb.collection('users').authWithPassword(email, password);
    user.set(pb.authStore.record);
}

export async function logout() {
    try {
        // Make a request to clear server-side session first
        await fetch('/api/logout', { 
            method: 'POST',
            credentials: 'include'
        });
        
        // Clear client-side auth
        pb.authStore.clear();
        user.set(null);
        
        // Clear all possible auth cookies on the client side
        if (typeof document !== 'undefined') {
            document.cookie = 'pb_auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; SameSite=Lax;';
            document.cookie = 'pb_auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; Domain=localhost; SameSite=Lax;';
            document.cookie = 'pb_auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; Domain=127.0.0.1; SameSite=Lax;';
        }
        
        // Force full page reload to ensure clean state
        if (typeof window !== 'undefined') {
            window.location.replace('/login');
        }
    } catch (error) {
        console.error('Error during logout:', error);
        // Clear client-side auth even if server call fails
        pb.authStore.clear();
        user.set(null);
        
        // Force reload even if logout API fails
        if (typeof window !== 'undefined') {
            window.location.replace('/login');
        }
    }
}

// API Client Settings Interface (keeping your existing interface)
export interface ApiClientSettings {
    id?: string;
    user?: string;
    host: string;
    apiKey: string;
    collectionId?: string;
    collectionName?: string;
    created?: string;
    updated?: string;
}

// Default values for new API client settings
export const defaultApiClientSettings: ApiClientSettings = {
    host: 'http://localhost:8000',
    apiKey: ''
};

// Create a writable store for the API client settings
export const apiClientSettings = writable<ApiClientSettings>(defaultApiClientSettings);

/**
 * Fetch the API client settings for the current user
 */
export async function fetchApiClientSettings(userId: string): Promise<ApiClientSettings> {
    try {
        // Fixed the query syntax
        const record = await pb.collection('api_clients').getFirstListItem(`user="${userId}"`);
        const settings: ApiClientSettings = {
            id: record.id,
            user: record.user,
            host: record.host,
            apiKey: record.apiKey,
            collectionId: record.collectionId,
            collectionName: record.collectionName,
            created: record.created,
            updated: record.updated
        };
        
        apiClientSettings.set(settings);
        return settings;
    } catch (error) {
        // If no settings found, return default
        apiClientSettings.set(defaultApiClientSettings);
        return defaultApiClientSettings;
    }
}

/**
 * Save API client settings for the current user
 */
export async function saveApiClientSettings(
    userId: string, 
    settings: ApiClientSettings
): Promise<ApiClientSettings> {
    try {
        // Check if settings already exist for this user
        let existingRecord = null;
        try {
            existingRecord = await pb.collection('api_clients').getFirstListItem(`user="${userId}"`);
        } catch {
            // No existing record found
        }
        
        if (existingRecord) {
            // Update existing record
            const updatedRecord = await pb.collection('api_clients').update(existingRecord.id, {
                host: settings.host,
                apiKey: settings.apiKey
            });
            
            const updatedSettings: ApiClientSettings = {
                id: updatedRecord.id,
                user: updatedRecord.user,
                host: updatedRecord.host,
                apiKey: updatedRecord.apiKey,
                collectionId: updatedRecord.collectionId,
                collectionName: updatedRecord.collectionName,
                created: updatedRecord.created,
                updated: updatedRecord.updated
            };
            
            apiClientSettings.set(updatedSettings);
            return updatedSettings;
        } else {
            // Create new record
            const newRecord = await pb.collection('api_clients').create({
                user: userId,
                host: settings.host,
                apiKey: settings.apiKey
            });
            
            const newSettings: ApiClientSettings = {
                id: newRecord.id,
                user: newRecord.user,
                host: newRecord.host,
                apiKey: newRecord.apiKey,
                collectionId: newRecord.collectionId,
                collectionName: newRecord.collectionName,
                created: newRecord.created,
                updated: newRecord.updated
            };
            
            apiClientSettings.set(newSettings);
            return newSettings;
        }
    } catch (error) {
        console.error('Error saving API client settings:', error);
        throw error;
    }
}

/**
 * Test the API connection using the current settings
 */
export async function testApiConnection(settings: ApiClientSettings): Promise<{ 
    success: boolean; 
    message: string; 
    data?: any;
}> {
    try {
        const response = await fetch(`${settings.host}/health`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': settings.apiKey
            }
        });

        if (!response.ok) {
            return {
                success: false,
                message: `Error ${response.status}: ${response.statusText}`
            };
        }

        const data = await response.json();
        return {
            success: true,
            message: `Connected to ${data.api} v${data.version}`,
            data
        };
    } catch (error) {
        return {
            success: false,
            message: `Connection failed: ${error instanceof Error ? error.message : String(error)}`
        };
    }
}