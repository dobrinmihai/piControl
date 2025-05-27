<script lang="ts">
    import Icon from "@iconify/svelte";

    let { data }: { data: { device: any } } = $props(); 
    let device = $state(data.device);

    let sensors = $state<any[]>([]);
    let isLoading = $state(true);
    let error = $state('');
    
    async function fetchSensors() {
    isLoading = true;
    error = '';
    try {
        const res = await fetch(`/api/esp-sensors?ip=${device.ip_addr}`);
        if (!res.ok) throw new Error('Could not fetch sensors');
        sensors = await res.json();
    } catch (e) {
        error = 'Could not fetch sensors from ESP32.';
    } finally {
        isLoading = false;
    }
}

    fetchSensors();
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <nav class="mb-6">
    <a
        href="/"
        class="inline-flex items-center font-mono text-sm text-neutral-800 hover:text-neutral-400"
    >
        <Icon icon="lucide:arrow-left" class="h-4 w-4 mr-2" />
        Back to Overview
    </a>
    </nav>
    <h1 class="font-mono text-2xl font-bold mb-4">Active sensors connected to {device.device_name}</h1>
    <p class="mb-4 font-mono text-sm text-neutral-500">IP: {device.ip_addr}</p>

    {#if isLoading}
        <div class="text-neutral-400">Loading sensors...</div>
    {:else if error}
        <div class="text-red-500">{error}</div>
    {:else if sensors.length === 0}
        <div class="text-neutral-400">No sensors found.</div>
    {:else}
        <div class="space-y-4">
            {#each sensors as sensor}
                <div class="border border-neutral-200 rounded p-4 bg-white">
                    <div class="font-mono text-sm font-bold">{sensor.name}</div>
                    <div class="font-mono text-xs text-neutral-500">Type: {sensor.type}</div>
                    <div class="font-mono text-xs">Value: {sensor.value}</div>
                </div>
            {/each}
        </div>
    {/if}
</div>