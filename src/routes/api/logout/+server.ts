import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ locals, cookies }) => {
    try {
        // Clear the PocketBase auth
        if (locals.pb) {
            locals.pb.authStore.clear();
        }
        locals.user = null;
        
        // Clear all possible auth cookies with different options
        const cookieOptions = [
            { path: '/' },
            { path: '/', domain: 'localhost' },
            { path: '/', domain: '127.0.0.1' },
            { path: '/', httpOnly: true },
            { path: '/', httpOnly: true, secure: false },
        ];
        
        for (const options of cookieOptions) {
            cookies.delete('pb_auth', options);
            cookies.set('pb_auth', '', {
                ...options,
                expires: new Date(0),
                sameSite: 'lax'
            });
        }
        
        return new Response(JSON.stringify({ success: true }), {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            }
        });
    } catch (error) {
        console.error('Error during logout:', error);
        return new Response(JSON.stringify({ 
            success: false, 
            error: 'Logout failed' 
        }), {
            status: 500,
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }
};
