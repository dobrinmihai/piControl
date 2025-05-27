<script lang="ts">
    import { pb } from "$lib/pocketbase.js";
    import Icon from "@iconify/svelte";
    import { onMount } from "svelte";
    
    let { data }: { data: { device: any, device_name: string } } = $props();
    let device = $state(data.device);
    
    // Tab state
    let activeTab = $state('packages');
    
    // Package management states
    let packageQuery = $state('');
    let installedPackageQuery = $state('');
    let installedPackages = $state<{name: string, version: string}[]>([]);
    let searchResults = $state<{name: string, description: string}[]>([]);
    let isLoadingPackages = $state(false);
    let isLoadingSearch = $state(false);
    let packageInstallList = $state<string[]>([]);
    
    // Service management states
    let services = $state<{
        name: string, 
        load_state: string,
        active_state: string,
        sub_state: string,
        description: string
    }[]>([]);
    let isLoadingServices = $state(false);
    let selectedService = $state('');
    let serviceStatus = $state<{
        success: boolean,
        service: string,
        active_status: string,
        enabled_status: string,
        full_status: string
    } | null>(null);
    
    async function loadInstalledPackages() {
        isLoadingPackages = true;
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=list_installed`);
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            const data = await response.json();
            installedPackages = data.packages || [];
        } catch (error) {
            console.error("Error loading installed packages:", error);
        } finally {
            isLoadingPackages = false;
        }
    }
    
    async function searchPackages() {
        if (!packageQuery.trim()) return;
        isLoadingSearch = true;
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=search&query=${packageQuery}`);
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            const data = await response.json();
            searchResults = data.results || [];
        } catch (error) {
            console.error("Error searching packages:", error);
        } finally {
            isLoadingSearch = false;
        }
    }
    
    function addToInstallList(pkg: string) {
        if (!packageInstallList.includes(pkg)) {
            packageInstallList = [...packageInstallList, pkg];
        }
    }
    
    function removeFromInstallList(pkg: string) {
        packageInstallList = packageInstallList.filter(p => p !== pkg);
    }
    
    async function installPackages() {
        if (packageInstallList.length === 0) return;
        isLoadingPackages = true;
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=install`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    packages: packageInstallList
                })
            });
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            
            // Clear install list and refresh installed packages
            packageInstallList = [];
            await loadInstalledPackages();
        } catch (error) {
            console.error("Error installing packages:", error);
        } finally {
            isLoadingPackages = false;
        }
    }
    
    async function uninstallPackage(pkg: string) {
        isLoadingPackages = true;
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=uninstall`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    packages: [pkg]
                })
            });
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            await loadInstalledPackages();
        } catch (error) {
            console.error("Error uninstalling package:", error);
        } finally {
            isLoadingPackages = false;
        }
    }
    
    async function loadServices() {
        isLoadingServices = true;
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=services`);
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            const data = await response.json();
            services = data.services || [];
        } catch (error) {
            console.error("Error loading services:", error);
        } finally {
            isLoadingServices = false;
        }
    }
    
    async function getServiceStatus(service: string) {
        selectedService = service;
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=service/status&name=${service}`);
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            const data = await response.json();
            serviceStatus = data;
        } catch (error) {
            console.error("Error getting service status:", error);
            serviceStatus = null;
        }
    }
    
    async function controlService(service: string, action: string) {
        try {
            const response = await fetch(`/api/helper-proxy?ip=${device.ip_addr}&endpoint=service/control`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    service,
                    action
                })
            });
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
            
            // Refresh service list and status
            await loadServices();
            if (selectedService === service) {
                await getServiceStatus(service);
            }
        } catch (error) {
            console.error(`Error controlling service:`, error);
        }
    }
    
    onMount(() => {
        if (activeTab === 'packages') {
            loadInstalledPackages();
        } else {
            loadServices();
        }
    });
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <nav class="mb-6">
        <a
            href="/devices/{device.device_name}"
            class="inline-flex items-center font-mono text-sm text-neutral-400 hover:text-white"
        >
            <Icon icon="lucide:arrow-left" class="h-4 w-4 mr-2" />
            Back to Device
        </a>
    </nav>

    <h1 class="font-mono text-3xl font-bold tracking-tight mb-8">
        Configure {device?.device_name || "Device"}
    </h1>

    <!-- Tabs -->
    <div class="border-b border-neutral-800 mb-6">
        <div class="flex">
            <button 
                class="px-4 py-2 font-mono text-sm {activeTab === 'packages' ? 'bg-neutral-100 border-b-2 border-black font-bold' : 'bg-white hover:bg-neutral-50'}"
                onclick={() => { activeTab = 'packages'; loadInstalledPackages(); }}
            >
                Packages
            </button>
            <button 
                class="px-4 py-2 font-mono text-sm {activeTab === 'services' ? 'bg-neutral-100 border-b-2 border-black font-bold' : 'bg-white hover:bg-neutral-50'}"
                onclick={() => { activeTab = 'services'; loadServices(); }}
            >
                Services
            </button>
        </div>
    </div>

    <!-- Packages Tab -->
    {#if activeTab === 'packages'}
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Installed Packages -->
            <div class="border border-neutral-800 bg-white">
                <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                    <h2 class="font-mono text-xl font-bold">Installed Packages</h2>
                </div>
                
                <div class="p-4">
                    <!-- Search for Already Installed Packages -->
                     <div class="mb-4 flex gap-2">
                        <input
                            type="text"
                            bind:value={installedPackageQuery}
                            placeholder="Search installed packages"
                            class="flex-grow bg-zinc border border-neutral-800 p-2 font-mono text-sm"
                            onkeydown={(e) => e.key === 'Enter' && e.preventDefault()}
                        />
                        <button
                            class="h-9 px-4 py-2 font-mono text-xs bg-white text-black hover:bg-neutral-200"
                            onclick={() => { /* No action needed, search is instant */ }}
                            type="button"
                        >
                            Search
                        </button>
                    </div>
                    {#if isLoadingPackages}
                        <div class="py-4 text-center">
                            <Icon icon="lucide:loader" class="h-5 w-5 mx-auto animate-spin text-neutral-500" />
                            <p class="font-mono text-sm text-neutral-500 mt-2">Loading packages...</p>
                        </div>
                    {:else if installedPackages.length === 0}
                        <div class="py-4 text-center border border-dashed border-neutral-300">
                            <p class="font-mono text-sm text-neutral-500">No packages found</p>
                        </div>
                    {:else}
                        <div class="border border-neutral-200 overflow-y-auto max-h-96">
                            <div class="grid grid-cols-12 bg-neutral-100 font-mono text-xs font-bold p-2">
                                <div class="col-span-8">Package</div>
                                <div class="col-span-3">Version</div>
                                <div class="col-span-1"></div>
                            </div>
                            {#each installedPackages.filter(pkg =>
                                pkg.name.toLowerCase().includes(installedPackageQuery.toLowerCase())
                            ) as pkg}
                                <div class="grid grid-cols-12 p-2 border-b border-neutral-200 last:border-b-0 items-center">
                                    <div class="col-span-8 font-mono text-sm">{pkg.name}</div>
                                    <div class="col-span-3 font-mono text-xs text-neutral-500">{pkg.version}</div>
                                    <div class="col-span-1">
                                        <button
                                            class="h-7 w-7 flex items-center justify-center text-red-500 hover:bg-red-50 rounded"
                                            onclick={() => uninstallPackage(pkg.name)}
                                            title="Uninstall package"
                                        >
                                            <Icon icon="lucide:trash-2" class="h-3 w-3" />
                                        </button>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {/if}
                </div>
            </div>
            
            <!-- Search and Install Packages -->
            <div class="border border-neutral-800 bg-white">
                <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                    <h2 class="font-mono text-xl font-bold">Install Packages</h2>
                </div>
                
                <div class="p-4">
                    <!-- Search Form -->
                    <div class="mb-4">
                        <div class="flex gap-2">
                            <input
                                type="text"
                                bind:value={packageQuery}
                                placeholder="Search packages"
                                class="flex-grow bg-zinc border border-neutral-800 p-2 font-mono text-sm"
                                onkeydown={(e) => e.key === 'Enter' && searchPackages()}
                            />
                            <button
                                class="h-9 px-4 py-2 font-mono text-xs bg-white text-black hover:bg-neutral-200"
                                onclick={searchPackages}
                            >
                                Search
                            </button>
                        </div>
                    </div>
                    
                    <!-- Search Results -->
                    {#if isLoadingSearch}
                        <div class="py-4 text-center">
                            <Icon icon="lucide:loader" class="h-5 w-5 mx-auto animate-spin text-neutral-500" />
                            <p class="font-mono text-sm text-neutral-500 mt-2">Searching packages...</p>
                        </div>
                    {:else if searchResults.length > 0}
                        <div class="mb-4">
                            <h3 class="font-mono text-md font-bold mb-2">Search Results</h3>
                            <div class="border border-neutral-200 overflow-y-auto max-h-48">
                                {#each searchResults as pkg}
                                    <div class="flex justify-between items-center p-2 border-b border-neutral-200 last:border-b-0">
                                        <div>
                                            <div class="font-mono text-sm">{pkg.name}</div>
                                            <div class="font-mono text-xs text-neutral-500">{pkg.description}</div>
                                        </div>
                                        <button
                                            class="h-7 px-2 font-mono text-xs bg-green-50 text-green-600 hover:bg-green-100 rounded"
                                            onclick={() => addToInstallList(pkg.name)}
                                        >
                                            <span class="flex items-center">
                                                <Icon icon="lucide:plus" class="h-3 w-3 mr-1" />
                                                Add
                                            </span>
                                        </button>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}
                    
                    <!-- Installation Queue -->
                    <div>
                        <h3 class="font-mono text-md font-bold mb-2">Installation Queue</h3>
                        {#if packageInstallList.length === 0}
                            <div class="py-4 text-center border border-dashed border-neutral-300">
                                <p class="font-mono text-sm text-neutral-500">No packages in queue</p>
                            </div>
                        {:else}
                            <div class="border border-neutral-200 mb-4">
                                {#each packageInstallList as pkg}
                                    <div class="flex justify-between items-center p-2 border-b border-neutral-200 last:border-b-0">
                                        <span class="font-mono text-sm">{pkg}</span>
                                        <button
                                            class="h-7 w-7 flex items-center justify-center text-red-500 hover:bg-red-50 rounded"
                                            onclick={() => removeFromInstallList(pkg)}
                                        >
                                            <Icon icon="lucide:x" class="h-3 w-3" />
                                        </button>
                                    </div>
                                {/each}
                            </div>
                            
                            <button
                                class="w-full h-9 px-4 py-2 font-mono text-xs bg-green-600 text-white hover:bg-green-700 flex items-center justify-center"
                                onclick={installPackages}
                                disabled={isLoadingPackages}
                            >
                                {#if isLoadingPackages}
                                    <Icon icon="lucide:loader" class="h-3 w-3 mr-2 animate-spin" />
                                    Installing...
                                {:else}
                                    <Icon icon="lucide:download" class="h-3 w-3 mr-2" />
                                    Install Selected Packages
                                {/if}
                            </button>
                        {/if}
                    </div>
                </div>
            </div>
        </div>
    {/if}

    <!-- Services Tab -->
    {#if activeTab === 'services'}
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Services List -->
            <div class="border border-neutral-800 bg-white">
                <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                    <h2 class="font-mono text-xl font-bold">System Services</h2>
                </div>
                
                <div class="p-4">
                    {#if isLoadingServices}
                        <div class="py-4 text-center">
                            <Icon icon="lucide:loader" class="h-5 w-5 mx-auto animate-spin text-neutral-500" />
                            <p class="font-mono text-sm text-neutral-500 mt-2">Loading services...</p>
                        </div>
                    {:else if services.length === 0}
                        <div class="py-4 text-center border border-dashed border-neutral-300">
                            <p class="font-mono text-sm text-neutral-500">No services found</p>
                        </div>
                    {:else}
                        <div class="border border-neutral-200 overflow-y-auto max-h-96">
                            <div class="grid grid-cols-12 bg-neutral-100 font-mono text-xs font-bold p-2">
                                <div class="col-span-8">Service</div>
                                <div class="col-span-4">Status</div>
                            </div>
                            {#each services as service}
                                <button
                                    class="grid grid-cols-12 p-2 border-b border-neutral-200 last:border-b-0 items-center hover:bg-neutral-50 cursor-pointer {selectedService === service.name ? 'bg-blue-50' : ''}"
                                    onclick={() => getServiceStatus(service.name)}
                                >
                                    <div class="col-span-8 font-mono text-sm">{service.name}</div>
                                    <div class="col-span-4">
                                        <span class="font-mono text-xs px-2 py-1 rounded 
                                            {service.active_state === 'active' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                                            {service.active_state}
                                        </span>
                                    </div>
                                </button>
                            {/each}
                        </div>
                    {/if}
                </div>
            </div>
            
            <!-- Service Details and Controls -->
            <div class="border border-neutral-800 bg-white">
                <div class="px-4 pt-4 pb-2 border-b border-neutral-800">
                    <h2 class="font-mono text-xl font-bold">Service Control</h2>
                </div>
                
                <div class="p-4">
                    {#if !selectedService}
                        <div class="py-4 text-center border border-dashed border-neutral-300">
                            <p class="font-mono text-sm text-neutral-500">Select a service to view details</p>
                        </div>
                    {:else if !serviceStatus}
                        <div class="py-4 text-center">
                            <Icon icon="lucide:loader" class="h-5 w-5 mx-auto animate-spin text-neutral-500" />
                            <p class="font-mono text-sm text-neutral-500 mt-2">Loading service details...</p>
                        </div>
                    {:else}
                        <div class="mb-4">
                            <h3 class="font-mono text-md font-bold mb-2">{serviceStatus.service}</h3>
                            
                            <div class="mb-4">
                                <div class="grid grid-cols-2 gap-2 mb-2">
                                    <div class="font-mono text-xs text-neutral-500">Active Status:</div>
                                    <div class="font-mono text-sm">{serviceStatus.active_status}</div>
                                    
                                    <div class="font-mono text-xs text-neutral-500">Enabled Status:</div>
                                    <div class="font-mono text-sm">{serviceStatus.enabled_status}</div>
                                </div>
                            </div>
                            
                            <div class="flex flex-wrap gap-2 mb-4">
                                <button
                                    class="h-8 px-3 font-mono text-xs bg-green-50 text-green-600 hover:bg-green-100 rounded"
                                    onclick={() => controlService(selectedService, 'start')}
                                >
                                    <span class="flex items-center">
                                        <Icon icon="lucide:play" class="h-3 w-3 mr-1" />
                                        Start
                                    </span>
                                </button>
                                <button
                                    class="h-8 px-3 font-mono text-xs bg-red-50 text-red-600 hover:bg-red-100 rounded"
                                    onclick={() => controlService(selectedService, 'stop')}
                                >
                                    <span class="flex items-center">
                                        <Icon icon="lucide:square" class="h-3 w-3 mr-1" />
                                        Stop
                                    </span>
                                </button>
                                <button
                                    class="h-8 px-3 font-mono text-xs bg-blue-50 text-blue-600 hover:bg-blue-100 rounded"
                                    onclick={() => controlService(selectedService, 'restart')}
                                >
                                    <span class="flex items-center">
                                        <Icon icon="lucide:refresh-cw" class="h-3 w-3 mr-1" />
                                        Restart
                                    </span>
                                </button>
                                
                                {#if serviceStatus.enabled_status.includes('enabled')}
                                    <button
                                        class="h-8 px-3 font-mono text-xs bg-yellow-50 text-yellow-600 hover:bg-yellow-100 rounded"
                                        onclick={() => controlService(selectedService, 'disable')}
                                    >
                                        <span class="flex items-center">
                                            <Icon icon="lucide:x-circle" class="h-3 w-3 mr-1" />
                                            Disable
                                        </span>
                                    </button>
                                {:else}
                                    <button
                                        class="h-8 px-3 font-mono text-xs bg-purple-50 text-purple-600 hover:bg-purple-100 rounded"
                                        onclick={() => controlService(selectedService, 'enable')}
                                    >
                                        <span class="flex items-center">
                                            <Icon icon="lucide:check-circle" class="h-3 w-3 mr-1" />
                                            Enable
                                        </span>
                                    </button>
                                {/if}
                            </div>
                            
                            <div>
                                <h4 class="font-mono text-sm font-bold mb-1">Full Status</h4>
                                <pre class="bg-neutral-100 p-3 font-mono text-xs overflow-x-auto whitespace-pre-wrap max-h-64 overflow-y-auto">{serviceStatus.full_status}</pre>
                            </div>
                        </div>
                    {/if}
                </div>
            </div>
        </div>
    {/if}
</div>