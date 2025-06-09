<script lang="ts">
    import type { Snippet } from 'svelte';
    import type { LayoutData } from './$types';
    import { user } from '$lib/auth';
    import { onMount } from 'svelte';
    import { page } from '$app/stores';
    import { goto } from '$app/navigation';
    import "../app.css"
    import Header from '$lib/components/Header.svelte';
    import Footer from '$lib/components/Footer.svelte';
    
    let { data, children }: { data: LayoutData, children: Snippet } = $props();
    
    // Sync server data with client store
    onMount(() => {
        // Always sync the user state from server data on mount
        user.set(data.user);
        
        // If server says not authenticated but client thinks it is, clear client state
        if (!data.user && $user) {
            user.set(null);
        }
    });
    
    // Also watch for changes in data.user during navigation
    $effect(() => {
        // Sync user state from server data
        user.set(data.user);
        
        // Client-side route protection with immediate redirect
        const isLoginPage = $page.url.pathname === '/login';
        const isAuthenticated = !!data.user;
        
        if (!isAuthenticated && !isLoginPage) {
            // Force immediate redirect without delay
            window.location.replace('/login');
        }
    });
</script>




<Header/>
{@render children()}
<Footer/>
