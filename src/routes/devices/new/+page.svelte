<script lang="ts">
    import { enhance } from '$app/forms';
    import type { PageData } from './$types';
    import { onMount } from 'svelte';
    import Icon from '@iconify/svelte';
    
    let { data }: { data: PageData & { networkDevices: { device_name?: string; mac_address: string; ip_address: string }[] } } = $props();
    let loading = $state(false);
    let scanning = $state(false);
    let error = $state("");
    let selectedDevices = $state<Record<string, boolean>>({});
    let existingDevices = $state<Record<string, boolean>>({});
    
    // Modal state variables
    let showModal = $state(false);
    let currentDevice = $state<{mac_address: string; ip_address: string} | null>(null);
    let deviceName = $state("");
    let deviceType = $state("raspberrypi");
    
    // Device type options
    const deviceTypes = [
        { id: "raspberrypi", name: "Raspberry Pi" },
        { id: "esp32", name: "ESP 32" }
    ];

    // Fetch existing devices from API
    async function fetchExistingDevices() {
        try {
            loading = true;
            const response = await fetch('/api/devices', {
                credentials: 'include'
            });
            
            if (!response.ok) {
                throw new Error('Failed to fetch devices');
            }
            
            const data = await response.json();
            
            // Create a map of existing MAC addresses
            const existingMap: Record<string, boolean> = {};
            data.devices.forEach((device: any) => {
                existingMap[device.mac_addr] = true;
            });
            
            existingDevices = existingMap;
        } catch (err) {
            console.error('Error fetching existing devices:', err);
            error = err instanceof Error ? err.message : 'Failed to fetch existing devices';
        } finally {
            loading = false;
        }
    }
    
    // Call fetchExistingDevices when component mounts
    onMount(() => {
        fetchExistingDevices();
    });

    // Simple function to mark a device as selected in the UI
    function selectDevice(device: any) {
        const deviceId = device.mac_address; // Use MAC as unique identifier
        selectedDevices[deviceId] = !selectedDevices[deviceId];
    }
    
    // Open modal with device data
    function openAddModal(device: any) {
        currentDevice = device;
        deviceName = device.device_name || "";
        showModal = true;
    }
    
    // Close modal and reset form
    function closeModal() {
        showModal = false;
        deviceName = "";
        currentDevice = null;
    }
    

    function handleRescanEnhance() {
    scanning = true;
    return ({ update }:any) => {
        scanning = false;
        update();
        fetchExistingDevices();
    };
}
    // Add device via API
    async function addDeviceToPocketBase() {
        if (!currentDevice) return;

        try {
            loading = true;
            error = "";

            console.log('Sending to API:', {
                device_name: deviceName,
                type: deviceType, // use 'type' everywhere
                mac_addr: currentDevice.mac_address,
                ip_addr: currentDevice.ip_address
            });

            const response = await fetch('/api/devices', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include',
                body: JSON.stringify({
                    device_name: deviceName,
                    type: deviceType, // use 'type' everywhere
                    mac_addr: currentDevice.mac_address,
                    ip_addr: currentDevice.ip_address
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to add device');
            }

            const result = await response.json();
            console.log('API response:', result);

            // Update both selected and existing device maps
            selectDevice(currentDevice);
            existingDevices[currentDevice.mac_address] = true;
            closeModal();
        } catch (err) {
            console.error('API error:', err);
            error = err instanceof Error ? err.message : 'Unknown error occurred';
        } finally {
            loading = false;
        }
    }
    
    // Check if a device is already in the database
    function isExistingDevice(macAddress: string): boolean {
        return !!existingDevices[macAddress];
    }
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <div class="flex justify-between items-center mb-8">
        <h1 class="font-mono text-3xl font-bold tracking-tight">Network Devices</h1>
        <div class="flex space-x-3">
            <form method="POST" action="?/rescan" use:enhance={handleRescanEnhance}>
                <button 
                    type="submit" 
                    class={`h-9 px-4 py-2 font-mono text-xs border border-neutral-800 bg-transparent hover:bg-neutral-200 inline-flex items-center ${scanning ? 'opacity-50' : ''}`}
                    disabled={scanning}
                >
                    <Icon icon="lucide:refresh-cw" class={`h-3 w-3 mr-2 ${scanning ? 'animate-spin' : ''}`} />
                    {scanning ? 'Scanning...' : 'Rescan Network'}
                </button>
            </form>
            <a href="/devices">
                <button class="h-9 px-4 py-2 font-mono text-xs border border-neutral-800 bg-transparent hover:bg-neutral-200 inline-flex items-center">
                    <Icon icon="lucide:arrow-left" class="h-3 w-3 mr-2" />
                    Back to Devices
                </button>
            </a>
        </div>
    </div>

    {#if error}
        <div class="border border-red-800 bg-red-900/20 p-4 mb-6">
            <p class="text-red-400 text-sm">{error}</p>
        </div>
    {/if}

    <div class="border border-neutral-800 bg-zinc-50 mb-8">
        <div class="px-4 pt-4 pb-2">
            <h2 class="font-mono text-xl font-bold">Available Devices on Network</h2>
            <p class="text-neutral-400 text-sm mt-1">These are the devices detected on your network</p>
        </div>
        
        <div class="p-4 pt-0">
            {#if data.networkDevices && data.networkDevices.length > 0}
                <table class="w-full">
                    <thead>
                        <tr class="border-b border-neutral-800">
                            <th class="text-left p-3 font-mono text-xs font-medium">MAC Address</th>
                            <th class="text-left p-3 font-mono text-xs font-medium">IP Address</th>
                            <th class="text-left p-3 font-mono text-xs font-medium">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {#each data.networkDevices as device}
                            {@const isExisting = isExistingDevice(device.mac_address)}
                            {@const isSelected = selectedDevices[device.mac_address]}
                            <tr 
                                class={`border-b border-neutral-800 ${
                                    isExisting ? 'opacity-50' : isSelected ? 'bg-neutral-800' : ''
                                }`}
                            >
                                <td class="p-3 font-mono text-sm">{device.mac_address}</td>
                                <td class="p-3 font-mono text-sm">{device.ip_address}</td>
                                <td class="p-3">
                                    {#if isExisting}
                                        <button 
                                            class="h-8 px-3 py-1 font-mono text-xs border border-neutral-800 bg-transparent opacity-50 cursor-not-allowed"
                                            disabled
                                        >
                                            Already Added
                                        </button>
                                    {:else if isSelected}
                                        <button 
                                            class="h-8 px-3 py-1 font-mono text-xs border border-neutral-800 bg-transparent opacity-50 cursor-not-allowed"
                                            disabled
                                        >
                                            Selected
                                        </button>
                                    {:else}
                                        <button 
                                            class="h-8 px-3 py-1 font-mono text-xs bg-white text-black hover:bg-neutral-200"
                                            onclick={() => openAddModal(device)}
                                        >
                                            Add
                                        </button>
                                    {/if}
                                </td>
                            </tr>
                        {/each}
                    </tbody>
                </table>
            {:else}
                <p class="text-neutral-400 py-4">No devices found on network</p>
            {/if}
        </div>
    </div>
</div>

{#if showModal && currentDevice}
<div class="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
    <div class="border border-neutral-800 bg-white w-full max-w-md">
        <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
            <h3 class="font-mono text-lg font-bold">Add New Device</h3>
        </div>
        
        <div class="p-4">
            <div class="space-y-4">
                <div>
                    <label for="mac" class="block font-mono text-xs mb-1">MAC Address:</label>
                    <input 
                        type="text" 
                        id="mac" 
                        value={currentDevice.mac_address} 
                        readonly 
                        class="w-full bg-white border border-neutral-800 p-2 font-mono text-sm"
                    />
                </div>
                
                <div>
                    <label for="ip" class="block font-mono text-xs mb-1">IP Address:</label>
                    <input 
                        type="text" 
                        id="ip" 
                        value={currentDevice.ip_address} 
                        readonly 
                        class="w-full bg-white border border-neutral-800 p-2 font-mono text-sm"
                    />
                </div>
                
                <div>
                    <label for="deviceName" class="block font-mono text-xs mb-1">Device Name:</label>
                    <input 
                        type="text" 
                        id="deviceName" 
                        bind:value={deviceName}
                        required 
                        placeholder="Enter device name" 
                        class="w-full bg-white border border-neutral-800 p-2 font-mono text-sm"
                    />
                </div>
                
                <div>
                    <label for="deviceType" class="block font-mono text-xs mb-1">Device Type:</label>
                    <div class="relative">
                        <select 
                            id="deviceType" 
                            bind:value={deviceType}
                            class="w-full appearance-none bg-white-900 border border-neutral-800 p-2 pr-8 font-mono text-sm rounded-none focus:outline-none focus:ring-1 focus:ring-white"
                        >
                            {#each deviceTypes as type}
                                <option value={type.id}>{type.name}</option>
                            {/each}
                        </select>
                        <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2">
                            <Icon icon="lucide:chevron-down" class="h-4 w-4 text-neutral-400" />
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="p-4 border-t border-neutral-800 flex justify-end space-x-3">
            <button 
                class="h-9 px-4 py-2 font-mono text-xs border border-zinc bg-transparent hover:bg-red-100 hover:border-red-500 text-black hover:text-red-500"
                onclick={closeModal}
            >
                Cancel
            </button>
            <button 
                class="h-9 px-4 py-2 font-mono text-xs bg-white text-black hover:bg-green-200 hover:border-green-500 hover:text-green-500 border border-zinc" 
                onclick={addDeviceToPocketBase}
            >
                Add Device
            </button>
        </div>
    </div>
</div>
{/if}