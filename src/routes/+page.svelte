<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { pb } from "$lib/pocketbase.js";
    import { user } from "$lib/auth";
    import { goto } from "$app/navigation";
    import Icon from "@iconify/svelte";

    let espDevices: any[] = [];
    let statuses: Record<string, string> = {};
    let loading = false;
    let error: string | null = null;
    let refreshing = false; // Separate state for refresh button

    // Debounced fetch function to prevent multiple concurrent requests
    let fetchTimeout: number | null = null;
    
    // Fetch all ESP32 devices from PocketBase
    async function fetchESPDevices(isRefresh = false) {
        console.log('=== fetchESPDevices called ===');
        console.log('Current user:', $user);
        
        if (!$user) {
            console.log('No authenticated user, skipping device fetch');
            error = 'Not authenticated';
            return;
        }
        
        // Prevent concurrent requests
        if (loading || refreshing) {
            console.log('Already loading or refreshing, skipping...');
            return;
        }
        
        if (isRefresh) {
            refreshing = true;
        } else {
            loading = true;
        }
        error = null;
        
        try {
            console.log('Making API request to /api/devices...');
            
            // Use the same API endpoint that works for devices page
            const response = await fetch('/api/devices');
            console.log('API response status:', response.status);
            console.log('API response headers:', Object.fromEntries(response.headers.entries()));
            
            if (!response.ok) {
                const errorText = await response.text();
                console.log('API error response:', errorText);
                throw new Error(`API returned ${response.status}: ${response.statusText} - ${errorText}`);
            }
            
            const data = await response.json();
            console.log('API response data:', data);
            const allDevices = data.devices || [];
            
            // Filter for ESP32 devices on the client side
            const esp32Devices = allDevices.filter((device: any) => {
                console.log('Device:', device.device_name, 'Type field:', device.type, 'Device_type field:', device.device_type);
                // Check both possible field names
                return device.type === "esp32" || device.device_type === "esp32";
            });
            
            espDevices = esp32Devices;
            console.log(`✓ Fetched ${allDevices.length} total devices, ${esp32Devices.length} ESP32 devices`);
            
            // Always check statuses when devices are fetched
            if (esp32Devices.length > 0) {
                await refreshStatuses();
            }
            // Hide loading immediately after fetch
            loading = false;
            refreshing = false;
        } catch (err: any) {
            console.error('❌ Error fetching ESP devices:', err);
            error = `Failed to load ESP32 devices: ${err.message}`;
            espDevices = [];
        } finally {
            // Remove or comment out loading = false; and refreshing = false; here to avoid double delay
        }
    }

    // Debounced refresh function
    function debouncedRefresh() {
        if (fetchTimeout) {
            clearTimeout(fetchTimeout);
        }
        
        fetchTimeout = setTimeout(() => {
            fetchESPDevices(true);
        }, 300); // 300ms debounce
    }

    // Refresh statuses for all devices
    async function refreshStatuses() {
        if (espDevices.length === 0) return;
        
        // Use Promise.allSettled to handle all requests concurrently
        const statusPromises = espDevices.map(async (device) => {
            try {
                const res = await fetch(`/api/esp-status?ip=${device.ip_addr}`);
                const statusData = await res.json();
                
                // Normalize status to "Online" or "Offline"
                let normalizedStatus = "Offline";
                if (statusData.status === "running" || statusData.status === "online") {
                    normalizedStatus = "Online";
                } else if (statusData.status === "offline" || statusData.status === "stopped") {
                    normalizedStatus = "Offline";
                }
                
                return { deviceId: device.id, status: normalizedStatus };
            } catch (error) {
                console.error(`Failed to get status for device ${device.device_name}:`, error);
                return { deviceId: device.id, status: "Offline" };
            }
        });
        
        const results = await Promise.allSettled(statusPromises);
        
        // Update statuses based on results
        results.forEach((result) => {
            if (result.status === 'fulfilled') {
                statuses[result.value.deviceId] = result.value.status;
            }
        });
        
        // Force reactivity update
        statuses = { ...statuses };
    }

    function viewSensors(device: any) {
        goto(`/${device.device_name}`);
    }

    let interval: number | null = null;
    let unsubscribe: any;

    onMount(() => {
        console.log('=== Overview page mounted ===');
        
        // Subscribe to user changes
        unsubscribe = user.subscribe(async (currentUser) => {
            console.log('=== User state changed ===');
            console.log('Current user:', currentUser);
            console.log('ESP devices length:', espDevices.length);
            console.log('Loading state:', loading);
            
            if (currentUser && espDevices.length === 0 && !loading) {
                console.log('✓ Conditions met, fetching ESP devices...');
                await fetchESPDevices();
                if (interval) clearInterval(interval);
                interval = setInterval(refreshStatuses, 10000); // Refresh every 10 seconds
            } else if (!currentUser) {
                console.log('❌ User logged out, clearing data');
                // User logged out, clear data
                espDevices = [];
                statuses = {};
                if (interval) {
                    clearInterval(interval);
                    interval = null;
                }
            } else {
                console.log('⏸️ Conditions not met for fetching devices');
            }
        });
    });

    onDestroy(() => {
        if (interval) {
            clearInterval(interval);
            interval = null;
        }
        if (unsubscribe) {
            unsubscribe();
        }
        if (fetchTimeout) {
            clearTimeout(fetchTimeout);
            fetchTimeout = null;
        }
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <div class="flex justify-between items-center mb-8">
        <div>
            <h1 class="font-mono text-3xl font-bold tracking-tight">Overview</h1>
            <h2 class="mt-2 font-mono text-lg text-neutral-600">Connected ESP32 Devices</h2>
        </div>
        <div class="flex space-x-2">
            <button 
                on:click={debouncedRefresh}
                disabled={loading || refreshing}
                class="px-4 py-2 bg-neutral-800 text-white rounded font-mono text-xs hover:bg-neutral-900 disabled:opacity-50 flex items-center"
            >
                <Icon icon="lucide:refresh-cw" class="h-3 w-3 mr-2 {(loading || refreshing) ? 'animate-spin' : ''}" />
                {refreshing ? 'Refreshing...' : loading ? 'Loading...' : 'Refresh Devices'}
            </button>
        </div>
    </div>
    
    {#if loading}
        <!-- Optionally, you can remove this block entirely or reduce the message -->
        <div class="flex items-center justify-center py-8">
            <Icon icon="lucide:refresh-cw" class="h-6 w-6 mr-2 animate-spin" />
            <span class="font-mono text-sm">Loading...</span>
        </div>
    {:else if error}
        <div class="bg-red-50 border border-red-200 rounded p-4 mb-4">
            <div class="flex items-center">
                <Icon icon="lucide:alert-circle" class="h-5 w-5 text-red-500 mr-2" />
                <span class="font-mono text-sm text-red-700">{error}</span>
            </div>
            <button 
                on:click={() => fetchESPDevices()}
                class="mt-2 px-3 py-1 bg-red-500 text-white rounded font-mono text-xs hover:bg-red-600"
            >
                Retry
            </button>
        </div>
    {:else if espDevices.length === 0}
        <p class="text-neutral-400 font-mono">No ESP32 devices found.</p>
    {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {#each espDevices as device}
                <div class="border border-neutral-400 bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow p-6">
                    <div class="flex gap-4 items-center">
                        <!-- ESP32 CPU Icon on the left, centered -->
                        <div class="flex-shrink-0 p-3 bg-blue-50 rounded-lg flex items-center justify-center">
                            <Icon 
                                icon="lucide:cpu" 
                                class="w-8 h-8 text-black"
                            />
                        </div>
                        
                        <!-- Device info on the right -->
                        <div class="flex-1 space-y-2">
                            <div>
                                <h3 class="font-mono text-lg font-bold text-neutral-900">{device.device_name}</h3>
                            </div>
                            
                            <div class="space-y-1">
                                <div class="flex items-center text-sm">
                                    <Icon icon="lucide:wifi" class="h-3 w-3 mr-2 text-neutral-500" />
                                    <span class="font-mono text-neutral-800 font-medium">{device.ip_addr}</span>
                                </div>
                                <div class="flex items-center text-sm">
                                    <span class="font-mono text-xs px-2 py-1 rounded ml-2
                                        {statuses[device.id] === 'Online' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'}">
                                        {statuses[device.id] || 'Checking...'}
                                    </span>
                                </div>
                            </div>
                            
                            <div class="pt-2">
                                {#if statuses[device.id] === 'Online'}
                                    <button
                                        class="w-full px-4 py-2 font-mono text-xs font-semibold bg-neutral-200 text-neutral-800 hover:bg-neutral-300 rounded transition-colors flex items-center justify-center border border-neutral-300"
                                        on:click={() => viewSensors(device)}
                                    >
                                        <Icon icon="lucide:settings" class="h-3 w-3 mr-2" />
                                        View Sensors
                                    </button>
                                {:else}
                                    <button
                                        class="w-full px-4 py-2 font-mono text-xs font-semibold bg-neutral-100 text-neutral-500 rounded cursor-not-allowed flex items-center justify-center border border-neutral-200"
                                        disabled
                                    >
                                        <Icon icon="lucide:wifi-off" class="h-3 w-3 mr-2" />
                                        Offline
                                    </button>
                                {/if}
                            </div>
                        </div>
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>