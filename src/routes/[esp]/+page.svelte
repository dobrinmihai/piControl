<script lang="ts">
    import Icon from "@iconify/svelte";
    import { onMount } from "svelte";

    let { data }: { data: { device: any } } = $props(); 
    let device = $state(data.device);

    let sensors = $state<any[]>([]);
    let isLoading = $state(true);
    let error = $state('');
    let refreshing = $state(false);
    let autoRefresh = $state(false);
    let refreshInterval: number | null = null;
    
    async function fetchSensors(isRefresh = false) {
        if (isRefresh) {
            refreshing = true;
        } else {
            isLoading = true;
        }
        error = '';
        
        try {
            const res = await fetch(`/api/esp-sensors?ip=${device.ip_addr}`);
            if (!res.ok) throw new Error('Could not fetch sensors');
            sensors = await res.json();
        } catch (e) {
            error = 'Could not fetch sensors from ESP32 device.';
            console.error('Error fetching sensors:', e);
        } finally {
            isLoading = false;
            refreshing = false;
        }
    }

    function toggleAutoRefresh() {
        autoRefresh = !autoRefresh;
        
        if (autoRefresh) {
            refreshInterval = setInterval(() => {
                fetchSensors(true);
            }, 5000); // Refresh every 5 seconds
        } else {
            if (refreshInterval) {
                clearInterval(refreshInterval);
                refreshInterval = null;
            }
        }
    }

    function getSensorIcon(type: string) {
        switch (type?.toLowerCase()) {
            case 'temperature':
                return 'lucide:thermometer';
            case 'humidity':
                return 'lucide:droplets';
            case 'pressure':
                return 'lucide:gauge';
            case 'light':
                return 'lucide:sun';
            case 'motion':
                return 'lucide:activity';
            case 'distance':
                return 'lucide:ruler';
            default:
                return 'lucide:cpu';
        }
    }

    function getSensorUnit(type: string) {
        switch (type?.toLowerCase()) {
            case 'temperature':
                return '°C';
            case 'humidity':
                return '%';
            case 'pressure':
                return 'hPa';
            case 'light':
                return 'lux';
            case 'distance':
                return 'cm';
            default:
                return '';
        }
    }

    onMount(() => {
        fetchSensors();
        
        return () => {
            if (refreshInterval) {
                clearInterval(refreshInterval);
            }
        };
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <nav class="mb-6">
        <a
            href="/"
            class="inline-flex items-center font-mono text-sm text-neutral-400 hover:text-white"
        >
            <Icon icon="lucide:arrow-left" class="h-4 w-4 mr-2" />
            Back to Overview
        </a>
    </nav>
    
    <div class="flex justify-between items-center mb-8">
        <div>
            <h1 class="font-mono text-3xl font-bold tracking-tight">ESP32 Sensors</h1>
            <p class="mt-2 font-mono text-sm text-neutral-400">
                Device: {device.device_name} • IP: {device.ip_addr}
            </p>
        </div>
        <div class="flex space-x-3">
            <button 
                onclick={() => fetchSensors(true)}
                disabled={refreshing}
                class={`h-9 px-4 py-2 font-mono text-xs border border-neutral-800 bg-transparent hover:bg-neutral-200 inline-flex items-center ${refreshing ? 'opacity-50' : ''}`}
            >
                <Icon icon="lucide:refresh-cw" class={`h-3 w-3 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
                {refreshing ? 'Refreshing...' : 'Refresh'}
            </button>
            <button 
                onclick={toggleAutoRefresh}
                class={`h-9 px-4 py-2 font-mono text-xs border border-neutral-800 inline-flex items-center ${
                    autoRefresh ? 'bg-green-600 text-white hover:bg-green-700' : 'bg-transparent hover:bg-neutral-200'
                }`}
            >
                <Icon icon="lucide:clock" class="h-3 w-3 mr-2" />
                Auto Refresh {autoRefresh ? 'ON' : 'OFF'}
            </button>
        </div>
    </div>

    {#if error}
        <div class="border border-red-800 bg-red-900/20 p-4 mb-6">
            <div class="flex items-center">
                <Icon icon="lucide:alert-circle" class="h-5 w-5 text-red-400 mr-2" />
                <p class="text-red-400 text-sm">{error}</p>
            </div>
            <button 
                onclick={() => fetchSensors()}
                class="mt-2 px-3 py-1 bg-red-500 text-white rounded font-mono text-xs hover:bg-red-600"
            >
                Retry
            </button>
        </div>
    {/if}

    {#if isLoading}
        <div class="border border-neutral-800 bg-neutral-900 p-6">
            <div class="flex items-center justify-center">
                <Icon icon="lucide:loader" class="h-6 w-6 mr-2 animate-spin text-neutral-400" />
                <span class="font-mono text-sm text-neutral-400">Loading sensor data...</span>
            </div>
        </div>
    {:else if sensors.length === 0}
        <div class="border border-neutral-800 bg-zinc-50 p-6">
            <div class="text-center">
                <Icon icon="lucide:cpu" class="h-12 w-12 mx-auto text-neutral-400 mb-4" />
                <h3 class="font-mono text-lg font-bold mb-2">No Sensors Found</h3>
                <p class="text-neutral-400 text-sm">No active sensors detected on this ESP32 device.</p>
            </div>
        </div>
    {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {#each sensors as sensor, index}
                <div class="border border-neutral-800 bg-white">
                    <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                        <div class="flex items-center justify-between">
                            <div class="flex items-center">
                                <Icon icon={getSensorIcon(sensor.type)} class="h-5 w-5 text-neutral-600 mr-2" />
                                <h3 class="font-mono text-lg font-bold">{sensor.name}</h3>
                            </div>
                            <span class="font-mono text-xs text-neutral-400 bg-neutral-100 px-2 py-1 rounded">
                                {sensor.type || 'Unknown'}
                            </span>
                        </div>
                    </div>
                    <div class="p-4">
                        <div class="text-center">
                            <div class="font-mono text-3xl font-bold text-neutral-800 mb-2">
                                {sensor.value}
                                <span class="text-lg text-neutral-500 ml-1">{getSensorUnit(sensor.type)}</span>
                            </div>
                            {#if sensor.description}
                                <p class="font-mono text-xs text-neutral-500">{sensor.description}</p>
                            {/if}
                        </div>
                        
                        {#if sensor.lastUpdated}
                            <div class="mt-4 pt-4 border-t border-neutral-200">
                                <div class="flex items-center justify-center text-xs text-neutral-400">
                                    <Icon icon="lucide:clock" class="h-3 w-3 mr-1" />
                                    <span class="font-mono">Last updated: {new Date(sensor.lastUpdated).toLocaleTimeString()}</span>
                                </div>
                            </div>
                        {/if}
                    </div>
                </div>
            {/each}
        </div>
        
        <div class="mt-8 border border-neutral-800 bg-zinc-50">
            <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                <h2 class="font-mono text-xl font-bold">Sensor Summary</h2>
            </div>
            <div class="p-4">
                <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div class="text-center">
                        <div class="font-mono text-2xl font-bold text-neutral-800">{sensors.length}</div>
                        <div class="font-mono text-xs text-neutral-500">Total Sensors</div>
                    </div>
                    <div class="text-center">
                        <div class="font-mono text-2xl font-bold text-green-600">
                            {sensors.filter(s => s.value !== null && s.value !== undefined).length}
                        </div>
                        <div class="font-mono text-xs text-neutral-500">Active</div>
                    </div>
                    <div class="text-center">
                        <div class="font-mono text-2xl font-bold text-blue-600">
                            {new Set(sensors.map(s => s.type)).size}
                        </div>
                        <div class="font-mono text-xs text-neutral-500">Types</div>
                    </div>
                    <div class="text-center">
                        <div class="font-mono text-2xl font-bold text-purple-600">
                            {autoRefresh ? '5s' : 'Manual'}
                        </div>
                        <div class="font-mono text-xs text-neutral-500">Refresh Rate</div>
                    </div>
                </div>
            </div>
        </div>
    {/if}
</div>