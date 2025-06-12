<script lang="ts">
    import { pb } from '$lib/pocketbase.js';
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';
    import { user } from '$lib/auth';
    import Icon from '@iconify/svelte';

    export let data // Assuming data is passed as a prop
    
    // Use devices from server-side data initially
    let devices = data.devices || [];
    
    // Add loading state
    let isLoading = false;
    let refreshing = false;
    
    // Function to handle clicking the Add Device button
    const handleAddDevice = () => {
        isLoading = true;
        // Navigate to the new device page after a brief delay to show the loader
        setTimeout(() => {
            goto('/devices/new');
        }, 300);
    };
    
    // Function to refresh devices from the API
    const refreshDevices = async () => {
        if (!$user) {
            console.log('No user, cannot refresh devices');
            return;
        }
        
        refreshing = true;
        try {
            console.log('Refreshing devices via API...');
            const response = await fetch('/api/devices');
            const data = await response.json();
            
            if (response.ok) {
                devices = data.devices || [];
                console.log('Devices refreshed via API:', devices);
                
                if (data.error) {
                    console.warn('API returned warning:', data.error);
                }
            } else {
                console.error('API response not ok:', response.status, data);
                
                // Fallback: try direct PocketBase call
                console.log('Trying direct PocketBase call as fallback...');
                try {
                    const records = await pb.collection('devices').getFullList({
                        sort: '-created',
                    });
                    devices = records;
                    console.log('Devices fetched via direct PocketBase:', devices);
                } catch (pbError) {
                    console.error('Direct PocketBase call also failed:', pbError);
                    // Try with owner filter
                    try {
                        const recordsWithOwner = await pb.collection('devices').getFullList({
                            filter: `owner = "${$user.id}"`,
                            sort: '-created',
                        });
                        devices = recordsWithOwner;
                        console.log('Devices fetched with owner filter:', devices);
                    } catch (ownerError) {
                        console.error('Owner filter also failed:', ownerError);
                    }
                }
            }
        } catch (error) {
            console.error('Error refreshing devices:', error);
        } finally {
            refreshing = false;
        }
    };
    
    // Only refresh on mount if we don't have devices from server
    onMount(() => {
        if (devices.length === 0 && $user) {
            refreshDevices();
        }
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <div class="flex justify-between items-center mb-8">
        <h1 class="font-mono text-3xl font-bold tracking-tight">Devices</h1>
        <div class="flex gap-2">
            {#if refreshing}
                <button class="h-9 px-4 py-2 font-mono text-xs bg-neutral-200 text-neutral-600 inline-flex items-center" disabled>
                    <Icon icon="lucide:refresh-cw" class="h-3 w-3 mr-2 animate-spin" /> Refreshing
                </button>
            {:else}
                <button on:click={refreshDevices} class="h-9 px-4 py-2 font-mono text-xs border border-neutral-300 hover:bg-neutral-50 inline-flex items-center">
                    <Icon icon="lucide:refresh-cw" class="h-3 w-3 mr-2" /> Refresh
                </button>
            {/if}
            
            {#if isLoading}
                <button class="h-9 px-4 py-2 font-mono text-xs bg-white text-black hover:bg-neutral-200 inline-flex items-center" aria-busy="true">
                    <Icon icon="lucide:refresh-cw" class="h-3 w-3 mr-2 animate-spin" /> Loading
                </button>
            {:else}
                <button on:click={handleAddDevice} class="h-9 px-4 py-2 font-mono text-xs bg-white text-black hover:bg-neutral-200 inline-flex items-center">
                    <svg class="h-3 w-3 mr-2" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 5v14m7-7H5"></path>
                    </svg>
                    Add Device
                </button>
            {/if}
        </div>
    </div>
    <table class="w-full">
        <thead>
            <tr class="bg-neutral-100">
                <th class="text-left font-mono text-xs p-2">Device Name</th>
                <th class="text-left font-mono text-xs p-2">MAC Address</th>
                <th class="text-left font-mono text-xs p-2">IP Address</th>
                <th class="text-left font-mono text-xs p-2">Actions</th>
            </tr>
        </thead>
        <tbody>
            {#each devices as device}
                <tr class="border-b border-neutral-200">
                    <td class="p-2 font-mono">{device.device_name}</td>
                    <td class="p-2 font-mono">{device.mac_addr}</td>
                    <td class="p-2 font-mono">{device.ip_addr}</td>
                    <td class="p-2">
                        <a href={`/devices/${device.device_name}`}>
                            <button class="h-8 px-3 py-1 font-mono text-xs bg-white text-black hover:bg-neutral-200">
                                View
                            </button>
                        </a>
                    </td>
                </tr>
            {/each}
        </tbody>
    </table>
</div>