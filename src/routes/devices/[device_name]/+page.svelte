<script lang="ts">
    
    let { data }: { data: { device: any } } = $props(); 
    import { pb } from "$lib/pocketbase.js";
    import { onMount } from "svelte";
    import { browser } from "$app/environment";
    import Icon from "@iconify/svelte";
    import SshModal from '$lib/components/SshModal.svelte';

    // Import Xterm CSS
    import "xterm/css/xterm.css";

    let device = $state(data.device);

    let term: any;
    let socket: any;
    let showCredentialsModal = $state(false);
    let showEditDeviceModal = $state(false);
    let showTerminalModal = $state(false);
    let sshUsername = $state("root");
    let loading = $state(false);
    let passwordInput = $state("");
    let sshHost = $state(device.ip_addr);
    let sshError = $state("");
    let sshLoading = $state(false);
    const deviceTypes = [
        { id: "raspberrypi", name: "Raspberry Pi" },
        { id: "esp32", name: "ESP 32" }
    ];

    let showDeleteConfirmModal = $state(false);
    let isDeleting = $state(false);


    async function getHelperStatus() {
    try {
        const response = await fetch(`/api/helper-status?ip=${device.ip_addr}`);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const status = await response.json();
        console.log("Helper status:", status);
        return status;
    } catch (error) {
        console.error("Error fetching helper status:", error);
        return null;
    }
}

    function openDeleteConfirmModal() {
        showDeleteConfirmModal = true;
    }

    function closeDeleteConfirmModal() {
        showDeleteConfirmModal = false;
    }

    let editFormData = $state({
        device_name: "",
        mac_addr: "",
        ip_addr: "",
        type: "",
    });

    function openEditDeviceModal() {
        // Create a deep copy of the device object
        editFormData = {
            device_name: device.device_name,
            mac_addr: device.mac_addr,
            ip_addr: device.ip_addr,
            type: device.type || "",
        };
        showEditDeviceModal = true;
    }
    function closeEditDeviceModal() {
        showEditDeviceModal = false;
    }

    async function updateDevice() {
        if (!device.id) {
            console.error("Device ID is missing. Cannot update device.", device);
            alert("Error: Device ID is missing. Cannot update device. Please contact support or check device data integrity.");
            return;
        }
        
        try {
            const response = await fetch(`/api/devices/${device.device_name}`, {
                method: 'PUT',
                headers:
                {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(editFormData)
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            const record = await response.json();
            console.log("Device updated:", record);
            
            // Update the main device object only after successful update
            device = {
                id: record.device.id,
                device_name: record.device.device_name,
                mac_addr: record.device.mac_addr,
                ip_addr: record.device.ip_addr,
                type: record.device.type,
            };
            closeEditDeviceModal();
        } catch (error) {
            console.error("Error updating device:", error, device, editFormData);
            alert("Failed to update device: " + (error instanceof Error ? error.message : String(error)));
        }
    }

    async function deleteDevice() {
        if (!device.id) {
            console.error("Device ID is missing. Cannot delete device.", device);
            alert("Error: Device ID is missing. Cannot delete device. Please contact support or check device data integrity.");
            isDeleting = false;
            closeDeleteConfirmModal();
            return;
        }
        
        isDeleting = true;
        try {
            const response = await fetch(`/api/devices/${device.device_name}`, {
                method: 'DELETE'
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            console.log("Device deleted");
            window.location.href = "/devices";
        } catch (error) {
            console.error("Error deleting device:", error, device);
            alert("Failed to delete device: " + (error instanceof Error ? error.message : String(error)));
            isDeleting = false;
            closeDeleteConfirmModal();
        }
    }

    function openCredentialsModal() {
        showCredentialsModal = true;
        sshError = "";
    }

    function cancelPasswordPrompt() {
        showCredentialsModal = false;
        passwordInput = "";
        sshError = "";
    }

    async function connectWithPassword({ username, host, password }: { username: string, host: string, password: string }) {
        showCredentialsModal = false;
        showTerminalModal = true;
        sshLoading = true;
        sshUsername = username;
        sshHost = host;
        if (browser) {
            setTimeout(() => {
                initTerminal(password);
            }, 100);
        }
        sshLoading = false;
    }

    async function initTerminal(password: string) {
        // Dynamically import Terminal only in the browser
        const { Terminal } = await import("xterm");

        // Initialize terminal
        term = new Terminal();
        const terminalElement = document.getElementById("terminal");
        if (terminalElement) {
            term.open(terminalElement);
        } else {
            console.error("Terminal element not found");
        }

        // Native WebSocket connection to Go backend
        socket = new WebSocket(`wss://localhost:3000/ws`);
        socket.onopen = () => {
            const msg = {
                type: "start_ssh",
                hostname: sshHost,
                username: sshUsername,
                password: password,
            };
            socket.send(JSON.stringify(msg));
        };
        socket.onmessage = (event: any) => {
            try {
                const data = JSON.parse(event.data);
                if (data.type === "ssh_data") {
                    term.write(data.data);
                } else if (data.type === "ssh_error") {
                    term.write(`\r\n\x1b[31m${data.data}\x1b[0m\r\n`);
                }
            } catch (e) {
                term.write(event.data);
            }
        };
        socket.onclose = () => {
            term.write("\r\n\x1b[31mDisconnected from server\x1b[0m\r\n");
        };
        term.onData((data: any) => {
            const msg = {
                type: "input",
                data
            };
            socket.send(JSON.stringify(msg));
        });
    }

    function closeTerminal() {
        if (socket) {
            socket.close();
        }
        if (term) {
            term.dispose();
            term = null;
        }
        showTerminalModal = false;
    }

    const fetchDevice = async () => {
        try {
            loading = true;
            const record = await pb
                .collection("devices")
                .getFirstListItem(`device_name="${data.device.device_name}"`);
            device = {
                id: record.id,
                device_name: record.device_name,
                mac_addr: record.mac_addr,
                ip_addr: record.ip_addr,
                type: record.type,
            };
        } catch (error) {
            console.error("Error fetching device:", error);
        } finally {
            loading = false;
        }
    };

    onMount(() => {
        // If needed, fetch the latest device data
        if (!device) {
            fetchDevice();
        }
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <nav class="mb-6">
        <a
            href="/devices"
            class="inline-flex items-center font-mono text-sm text-neutral-800 hover:text-neutral-400"
        >
            <Icon icon="lucide:arrow-left" class="h-4 w-4 mr-2" />
            Back to Devices
        </a>
    </nav>

    <h1 class="font-mono text-3xl font-bold tracking-tight mb-8">
        {device?.device_name || "Device Details"}
    </h1>

    {#if loading}
        <div class="border border-neutral-800 bg-neutral-900 p-6">
            <p class="text-neutral-400">Loading device information...</p>
        </div>
    {:else if device}
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Device Information Card -->
            <div class="border border-neutral-800 bg-white">
                <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                    <h2 class="font-mono text-xl font-bold">
                        Device Information
                    </h2>
                </div>
                <div class="p-4">
                    <div class="border-b border-neutral-800 py-3">
                        <div class="flex justify-between">
                            <span class="font-mono text-sm text-neutral-400"
                                >Name:</span
                            >
                            <span class="font-mono text-sm"
                                >{device.device_name}</span
                            >
                        </div>
                    </div>
                    <div class="border-b border-neutral-800 py-3">
                        <div class="flex justify-between">
                            <span class="font-mono text-sm text-neutral-400"
                                >MAC Address:</span
                            >
                            <span class="font-mono text-sm"
                                >{device.mac_addr}</span
                            >
                        </div>
                    </div>
                    <div class="border-b border-neutral-800 py-3">
                        <div class="flex justify-between">
                            <span class="font-mono text-sm text-neutral-400"
                                >IP Address:</span
                            >
                            <span class="font-mono text-sm"
                                >{device.ip_addr}</span
                            >
                        </div>
                    </div>
                    <div class="py-3">
                        <div class="flex justify-between">
                            <span class="font-mono text-sm text-neutral-400"
                                >Type:</span
                            >
                            <span class="font-mono text-sm"
                                >{device.type || "N/A"}</span
                            >
                        </div>
                    </div>
                </div>
            </div>

            <!-- Device Management Card -->
            <div class="border border-neutral-800 bg-white">
                <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                    <h2 class="font-mono text-xl font-bold">
                        Device Management
                    </h2>
                </div>
                <div class="p-4">
                    <div class="flex flex-col space-y-3">
                        <button
                            class="h-9 px-4 py-2 font-mono text-xs bg-white text-black border border-neutral-800 hover:bg-neutral-200 inline-flex items-center justify-center"
                            onclick={openEditDeviceModal}
                        >
                            <Icon icon="lucide:edit" class="h-3 w-3 mr-2" />
                            Edit Device
                        </button>
                        <button
                            class="h-9 px-4 py-2 font-mono text-xs border border-red-800 text-red-500 bg-transparent hover:bg-red-900/20 inline-flex items-center justify-center"
                            onclick={openDeleteConfirmModal}
                        >
                            <Icon icon="lucide:trash-2" class="h-3 w-3 mr-2" />
                            Delete Device
                        </button>
                         {#if device.type === "raspberrypi"}
                            <button
                                class="h-9 px-4 py-2 font-mono text-xs border border-neutral-800 bg-transparent hover:bg-white inline-flex items-center justify-center"
                                onclick={openCredentialsModal}
                            >
                                <Icon icon="lucide:terminal" class="h-3 w-3 mr-2" />
                                Connect to SSH
                            </button>
                        {:else if device.type === "esp32"}
                        <span></span>
                        {:else}
                            <span class="text-red-500 font-mono text-xs">
                                Unsupported device type for SSH connection
                            </span>
                        {/if}
                        {#if device.type === "raspberrypi"}
                            {#await getHelperStatus() then status}
                                <!-- Helper Status -->              
                                <div class="border-b border-neutral-800 py-3">
                                    <div class="flex justify-between items-center">
                                        <span class="font-mono text-sm text-neutral-400">Helper Status:</span>
                                        <div class="flex items-center gap-2">
                                            {#if status}
                                                <span class="inline-block w-2 h-2 rounded-full 
                                                    {status.status === 'running' ? 'bg-green-500' : 'bg-red-500'}"></span>
                                                <span class="font-mono text-sm">{status.status || "Unknown"}</span>
                                                {#if status.distribution}
                                                    <span class="font-mono text-xs text-neutral-400">({status.distribution})</span>
                                                {/if}
                                                
                                                {#if status.status === 'running'}
                                                    <a 
                                                        href="/devices/{device.device_name}/config" 
                                                        class="ml-3 h-7 px-3 py-1 font-mono text-xs bg-green-600 text-white hover:bg-green-700 inline-flex items-center justify-center rounded"
                                                    >
                                                        <Icon icon="lucide:settings" class="h-3 w-3 mr-1" />
                                                        Configure
                                                    </a>
                                                {/if}
                                            {:else}
                                                <span class="inline-block w-2 h-2 rounded-full bg-gray-500"></span>
                                                <span class="font-mono text-sm">Not available</span>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            {/await}
                        {/if}
                    </div>
                </div>
            </div>
        </div>
    {:else}
        <div class="border border-neutral-800 bg-neutral-900 p-6">
            <p class="text-neutral-400">Device not found</p>
        </div>
    {/if}
</div>

<!-- Delete Confirmation Modal -->
{#if showDeleteConfirmModal}
    <div
        class="fixed inset-0 bg-black/80 flex items-center justify-center z-50"
    >
        <div class="border border-neutral-800 bg-white w-full max-w-md">
            <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                <h3 class="font-mono text-lg font-bold">Confirm Deletion</h3>
            </div>

            <div class="p-4">
                <p class="font-mono text-sm">
                    Are you sure you want to delete <span class="font-bold"
                        >{device.device_name}</span
                    >? This action cannot be undone.
                </p>
            </div>

            <div
                class="p-4 border-t border-neutral-800 flex justify-end space-x-3"
            >
                <button
                    class="h-9 px-4 py-2 font-mono text-xs border border-neutral-800 bg-transparent hover:bg-neutral-200"
                    onclick={closeDeleteConfirmModal}
                    disabled={isDeleting}
                >
                    Cancel
                </button>
                <button
                    class="h-9 px-4 py-2 font-mono text-xs border border-red-800 text-white bg-red-600 hover:bg-red-700 inline-flex items-center justify-center"
                    onclick={deleteDevice}
                    disabled={isDeleting}
                >
                    {#if isDeleting}
                        <Icon
                            icon="lucide:loader"
                            class="h-3 w-3 mr-2 animate-spin"
                        />
                        Deleting...
                    {:else}
                        <Icon icon="lucide:trash-2" class="h-3 w-3 mr-2" />
                        Delete Device
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/if}

{#if showEditDeviceModal}
    <div
        class="fixed inset-0 bg-black/80 flex items-center justify-center z-50"
    >
        <div class="border border-neutral-800 bg-white w-full max-w-md">
            <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                <h3 class="font-mono text-lg font-bold">Edit Device</h3>
            </div>

            <div class="p-4">
                <div class="space-y-4">
                    <div>
                        <label
                            for="deviceName"
                            class="block font-mono text-xs mb-1"
                        >
                            Device Name
                        </label>
                        <input
                            type="text"
                            id="deviceName"
                            bind:value={editFormData.device_name}
                            placeholder="Device Name"
                            required
                            class="w-full bg-zinc border border-neutral-800 p-2 font-mono text-sm"
                        />
                    </div>

                    <div>
                        <label for="deviceType" class="block font-mono text-xs mb-1">Device Type:</label>
                        <div class="relative">
                            <select 
                                id="deviceType" 
                                bind:value={editFormData.type}
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
                    <div>
                        <label
                            for="deviceIp"
                            class="block font-mono text-xs mb-1"
                        >
                            IP Address
                        </label>
                        <input
                            type="text"
                            id="deviceIp"
                            bind:value={editFormData.ip_addr}
                            placeholder="Device IP Address"
                            class="w-full bg-zinc border border-neutral-800 p-2 font-mono text-sm"
                        />
                    </div>
                    <div>
                        <label
                            for="deviceMac"
                            class="block font-mono text-xs mb-1"
                        >
                            MAC Address
                        </label>
                        <input
                            type="text"
                            id="deviceMac"
                            bind:value={editFormData.mac_addr}
                            placeholder="Device MAC Address"
                            class="w-full bg-zinc border border-neutral-800 p-2 font-mono text-sm"
                        />
                    </div>
                </div>
            </div>

            <div
                class="p-4 border-t border-neutral-800 flex justify-end space-x-3"
            >
                <button
                    class="h-9 px-4 py-2 font-mono text-xs border border-neutral-800 bg-transparent hover:bg-neutral-200"
                    onclick={closeEditDeviceModal}
                >
                    Cancel
                </button>
                <button
                    class="h-9 px-4 py-2 font-mono text-xs bg-white text-black hover:bg-neutral-200"
                    onclick={updateDevice}
                >
                    Save Changes
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- SSH Credentials Modal -->
<SshModal
  show={showCredentialsModal}
  username={sshUsername}
  host={sshHost}
  password={passwordInput}
  loading={sshLoading}
  error={sshError}
  onCancel={cancelPasswordPrompt}
  onConnect={connectWithPassword}
/>

<!-- Terminal Modal -->
{#if showTerminalModal}
    <div class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50">
        <div class="bg-neutral-900 border border-neutral-800 rounded shadow-lg w-full max-w-4xl h-3/4">
            <div class="p-4 border-b border-neutral-800">
                <h3 class="text-white font-mono text-sm mb-1">
                    SSH Terminal: {sshUsername}@{device?.ip_addr}
                </h3>
            </div>

            <div class="p-4 h-[calc(100%-8rem)]">
                <div
                    id="terminal"
                    class="w-full h-full bg-black border border-neutral-800 font-mono text-sm p-2 overflow-auto rounded"
                ></div>
            </div>

            <div class="p-4 border-t border-neutral-800 flex justify-end">
                <button
                    class="px-3 py-1 text-xs font-mono bg-neutral-800 text-white hover:bg-neutral-700"
                    onclick={closeTerminal}
                >
                    Close Terminal
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    /* Any additional custom styles can go here */
    :global(.xterm) {
        height: 100%;
        padding: 0.5rem;
    }
</style>