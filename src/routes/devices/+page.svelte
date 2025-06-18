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
        <div>
            <h1 class="font-mono text-3xl font-bold tracking-tight">Devices</h1>
            <h2 class="mt-2 font-mono text-lg text-neutral-600">Manage Your Connected Devices</h2>
        </div>
        <div class="flex gap-2">
            {#if refreshing}
                <button class="px-4 py-2 font-mono text-xs bg-neutral-200 text-neutral-600 rounded inline-flex items-center" disabled>
                    <Icon icon="lucide:refresh-cw" class="h-4 w-4 mr-2 animate-spin" /> Refreshing
                </button>
            {:else}
                <button on:click={refreshDevices} class="px-4 py-2 font-mono text-xs border border-neutral-300 hover:bg-neutral-50 rounded inline-flex items-center transition-colors">
                    <Icon icon="lucide:refresh-cw" class="h-4 w-4 mr-2" /> Refresh
                </button>
            {/if}
            
            {#if isLoading}
                <button class="px-4 py-2 font-mono text-xs bg-neutral-800 text-white rounded inline-flex items-center" aria-busy="true">
                    <Icon icon="lucide:refresh-cw" class="h-4 w-4 mr-2 animate-spin" /> Loading
                </button>
            {:else}
                <button on:click={handleAddDevice} class="px-4 py-2 font-mono text-xs bg-neutral-800 text-white hover:bg-neutral-900 rounded inline-flex items-center transition-colors">
                    <Icon icon="lucide:plus" class="h-4 w-4 mr-2" />
                    Add Device
                </button>
            {/if}
        </div>
    </div>

    {#if devices.length === 0}
        <div class="text-center py-12">
            <Icon icon="lucide:router" class="h-16 w-16 mx-auto text-neutral-400 mb-4" />
            <h3 class="font-mono text-lg font-semibold text-neutral-600 mb-2">No devices found</h3>
            <p class="font-mono text-sm text-neutral-500 mb-6">Start by adding your first device to the network</p>
            <button on:click={handleAddDevice} class="px-6 py-3 font-mono text-sm bg-blue-600 text-white hover:bg-blue-700 rounded inline-flex items-center transition-colors">
                <Icon icon="lucide:plus" class="h-4 w-4 mr-2" />
                Add Your First Device
            </button>
        </div>
    {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {#each devices as device}
                <div class="border border-neutral-400 bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow p-6">
                    <div class="flex gap-4 items-center">
                        <!-- Device Icon/Image -->
                        <div class="flex-shrink-0 p-3 bg-blue-50 rounded-lg flex items-center justify-center">
                            {#if device.type === 'esp32'}
                                <Icon 
                                    icon="lucide:cpu" 
                                    class="h-8 w-8 text-black"
                                />
                            {:else}
                                <Icon 
                                    icon="lucide:router" 
                                    class="h-8 w-8 text-black" 
                                />
                            {/if}
                        </div>
                        
                        <!-- Device Info -->
                        <div class="flex-1 space-y-2">
                            <div>
                                <h3 class="font-mono text-lg font-bold text-neutral-900">{device.device_name}</h3>
                                <span class="inline-block px-2 py-1 text-xs font-mono rounded-full border mr-2
                                  {device.type === 'raspberrypi' ? 'bg-red-100 text-red-700 border-red-400' : ''}
                                  {device.type === 'esp32' ? 'bg-blue-100 text-blue-700 border-blue-400' : ''}">
                                  {device.type === 'raspberrypi' ? 'Raspberry Pi' : device.type === 'esp32' ? 'ESP32' : device.type}
                                </span>
                            </div>
                            
                            <div class="space-y-1">
                                <div class="flex items-center text-sm">
                                    <Icon icon="lucide:wifi" class="h-3 w-3 mr-2 text-neutral-500" />
                                    <span class="font-mono text-neutral-800 font-medium">{device.ip_addr}</span>
                                </div>
                                <div class="flex items-center text-sm">
                                    <Icon icon="lucide:fingerprint" class="h-3 w-3 mr-2 text-neutral-500" />
                                    <span class="font-mono text-neutral-800 font-medium text-xs">{device.mac_addr}</span>
                                </div>
                            </div>
                            
                            <div class="pt-2">
                                <a href={`/devices/${device.device_name}`} class="w-full">
                                    <button class="w-full px-4 py-2 font-mono text-xs font-semibold bg-neutral-200 text-neutral-800 hover:bg-neutral-300 rounded transition-colors flex items-center justify-center border border-neutral-300">
                                        <Icon icon="lucide:settings" class="h-3 w-3 mr-2" />
                                        Configure
                                    </button>
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>