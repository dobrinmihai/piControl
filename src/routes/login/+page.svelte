<script lang="ts">
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { login, user } from '$lib/auth';
    import { onMount } from 'svelte';
    
    let email = $state('');
    let password = $state('');
    let isLoading = $state(false);
    let error = $state('');
    
    // Redirect if already logged in
    onMount(() => {
        const unsubscribe = user.subscribe((userData) => {
            if (userData) {
                goto($page.url.searchParams.get('redirectTo') || '/');
            }
        });
        
        return unsubscribe;
    });
    
    async function handleLogin() {
        if (!email || !password) {
            error = 'Please fill in all fields';
            return;
        }
        
        isLoading = true;
        error = '';
        
        try {
            await login(email, password);
            // Redirect will happen automatically via the user store subscription
        } catch (err) {
            error = err instanceof Error ? err.message : 'Login failed';
        } finally {
            isLoading = false;
        }
    }
    
    function handleSubmit(event: Event) {
        event.preventDefault();
        handleLogin();
    }
</script>

<svelte:head>
    <title>Login - piControl</title>
</svelte:head>

<div class="min-h-screen bg-neutral-900 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
        <div>
            <h2 class="mt-6 text-center text-3xl font-extrabold text-white">
                Sign in to piControl
            </h2>
            <p class="mt-2 text-center text-sm text-neutral-400">
                IoT Device Management Platform
            </p>
        </div>
        
        <form class="mt-8 space-y-6" on:submit={handleSubmit}>
            <input type="hidden" name="remember" value="true" />
            <div class="rounded-md shadow-sm space-y-4">
                <div>
                    <label for="email-address" class="block text-sm font-medium text-neutral-300 mb-2">
                        Email address
                    </label>
                    <input
                        id="email-address"
                        name="email"
                        type="email"
                        autocomplete="email"
                        required
                        bind:value={email}
                        class="appearance-none relative block w-full px-3 py-2 border border-neutral-600 placeholder-neutral-400 text-white bg-neutral-800 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 focus:z-10 sm:text-sm"
                        placeholder="Enter your email"
                    />
                </div>
                <div>
                    <label for="password" class="block text-sm font-medium text-neutral-300 mb-2">
                        Password
                    </label>
                    <input
                        id="password"
                        name="password"
                        type="password"
                        autocomplete="current-password"
                        required
                        bind:value={password}
                        class="appearance-none relative block w-full px-3 py-2 border border-neutral-600 placeholder-neutral-400 text-white bg-neutral-800 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 focus:z-10 sm:text-sm"
                        placeholder="Enter your password"
                    />
                </div>
            </div>

            {#if error}
                <div class="rounded-md bg-red-900 border border-red-600 p-4">
                    <div class="text-sm text-red-300">
                        {error}
                    </div>
                </div>
            {/if}

            <div>
                <button
                    type="submit"
                    disabled={isLoading}
                    class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {#if isLoading}
                        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Signing in...
                    {:else}
                        Sign in
                    {/if}
                </button>
            </div>
            
            <div class="mt-6">
                <div class="relative">
                    <div class="absolute inset-0 flex items-center">
                        <div class="w-full border-t border-neutral-600" />
                    </div>
                    <div class="relative flex justify-center text-sm">
                        <span class="px-2 bg-neutral-900 text-neutral-400">Need an account?</span>
                    </div>
                </div>
                
                <div class="mt-6 text-center">
                    <p class="text-sm text-neutral-400">
                        Registration is managed by system administrators.
                    </p>
                    <p class="text-sm text-neutral-300 mt-2">
                        Please contact your system administrator to create an account.
                    </p>
                </div>
            </div>
        </form>
    </div>
</div>
