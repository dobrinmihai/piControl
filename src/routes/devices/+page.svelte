<script lang="ts">
    import { pb } from '$lib/pocketbase.js';
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';
    import Icon from '@iconify/svelte';

    export let data // Assuming data is passed as a prop
    
    // Use devices from server-side data initially
    $: devices = data.devices;
    
    // Add loading state
    let isLoading = false;
    
    // Function to handle clicking the Add Device button
    const handleAddDevice = () => {
        isLoading = true;
        // Navigate to the new device page after a brief delay to show the loader
        setTimeout(() => {
            goto('/devices/new');
        }, 300);
    };
    
    // Function to fetch devices from PocketBase
    const fetchDevices = async () => {
        try {
            const records = await pb.collection('devices').getFullList({
                sort: 'device_name',
            });
            devices = records;
            console.log('Devices fetched:', devices);
        } catch (error) {
            console.error('Error fetching devices:', error);
        }
    };
    
    // Fetch devices when component mounts
    onMount(() => {
        fetchDevices();
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <div class="flex justify-between items-center mb-8">
        <h1 class="font-mono text-3xl font-bold tracking-tight">Devices</h1>
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