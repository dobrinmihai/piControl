<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { pb } from "$lib/pocketbase.js";
    import { goto } from "$app/navigation";
    import Icon from "@iconify/svelte";

    let espDevices: any[] = [];
    let statuses: Record<string, string> = {};

    // Fetch all ESP32 devices from PocketBase (only once)
    async function fetchESPDevices() {
        const records = await pb.collection("devices").getFullList({
            filter: 'type="esp32"',
            sort: 'device_name'
        });
        espDevices = records;
        await refreshStatuses();
    }

    // Refresh statuses for all devices
    async function refreshStatuses() {
        for (const device of espDevices) {
            try {
                const res = await fetch(`/api/esp-status?ip=${device.ip_addr}`);
                const status = await res.json();
                statuses[device.id] = status?.status === "running" ? "Online" : "Offline";
            } catch {
                statuses[device.id] = "Offline";
            }
        }
    }

    function viewSensors(device: any) {
        goto(`/${device.device_name}`);
    }

    let interval: any;

    onMount(async () => {
        await fetchESPDevices();
        interval = setInterval(refreshStatuses, 5000); // Refresh every 5 seconds
    });

    onDestroy(() => {
        clearInterval(interval);
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <h1 class="font-mono text-3xl font-bold tracking-tight mb-8">Overview</h1>
    <h2 class="mt-6 mb-2 font-mono text-lg">Connected ESP32 Devices</h2>
    {#if espDevices.length === 0}
        <p class="text-neutral-400">No ESP32 devices found.</p>
    {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {#each espDevices as device}
                <div class="border border-neutral-800 bg-white rounded shadow p-4">
                    <div class="border-b border-neutral-800 pb-2 mb-2">
                        <span class="font-mono text-sm text-neutral-400">Name:</span>
                        <span class="font-mono text-sm ml-2">{device.device_name}</span>
                    </div>
                    <div class="border-b border-neutral-800 pb-2 mb-2">
                        <span class="font-mono text-sm text-neutral-400">IP Address:</span>
                        <span class="font-mono text-sm ml-2">{device.ip_addr}</span>
                    </div>
                    <div class="pb-2 mb-2 flex items-center">
                        <span class="font-mono text-sm text-neutral-400">Status:</span>
                        <span class="font-mono text-xs px-2 py-1 rounded ml-2
                            {statuses[device.id] === 'Online' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'}">
                            {statuses[device.id] || 'Checking...'}
                        </span>
                        {#if statuses[device.id] === 'Online'}
                            <button
                                class="ml-auto px-3 py-1 bg-gray-700 text-white rounded font-mono text-xs hover:bg-gray-900 flex items-center"
                                on:click={() => viewSensors(device)}
                            >
                                <Icon icon="lucide:settings" class="h-3 w-3 mr-1" />
                                View Sensors
                            </button>
                        {/if}
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>