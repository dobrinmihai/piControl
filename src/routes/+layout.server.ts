import { redirect } from '@sveltejs/kit';
import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url, locals }) => {
    const isAuthenticated = locals.pb?.authStore.isValid || false;
    const currentUser = locals.user;
    
    // Define public routes that don't require authentication
    const publicRoutes = ['/login'];
    const isPublicRoute = publicRoutes.some(route => url.pathname === route);
    
    // If not authenticated and trying to access a protected route, redirect to login
    if (!isAuthenticated && !isPublicRoute) {
        const redirectTo = url.pathname + url.search;
        throw redirect(302, `/login?redirectTo=${encodeURIComponent(redirectTo)}`);
    }
    
    // If authenticated and trying to access login page, redirect to home
    if (isAuthenticated && url.pathname === '/login') {
        throw redirect(302, '/');
    }
    
    return {
        user: currentUser,
        isAuthenticated
    };
};
