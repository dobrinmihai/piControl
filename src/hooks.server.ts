import PocketBase from 'pocketbase';
import {redirect, type Handle} from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
    event.locals.pb = new PocketBase('http://localhost:8090');

    event.locals.pb.authStore.loadFromCookie(event.request.headers.get('cookie') || '');

    try {
        if (event.locals.pb.authStore.isValid) {
            await event.locals.pb.collection('users').authRefresh();
        }
    } catch (error) {
        console.error('Error refreshing auth:', error);
        event.locals.pb.authStore.clear();
    }

    event.locals.user = event.locals.pb.authStore.model;

    const response = await resolve(event);
    
    // Update locals.user after resolving in case it was modified
    event.locals.user = event.locals.pb.authStore.model;
    
    // Always set the cookie with current auth state
    const cookieValue = event.locals.pb.authStore.exportToCookie({ 
        httpOnly: true, 
        secure: false,
        path: '/',
        sameSite: 'lax'
    });
    
    response.headers.set('set-cookie', cookieValue);

    return response;
}