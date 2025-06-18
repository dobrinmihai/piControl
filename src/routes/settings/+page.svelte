<script lang="ts">
    import Icon from '@iconify/svelte';
</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <div class="mb-8">
        <h1 class="font-mono text-3xl font-bold tracking-tight">Settings</h1>
    </div>

    <!-- System Information -->
    <div class="mt-0 bg-white border border-neutral-200 rounded-lg shadow-sm p-6">
        <div class="flex items-center gap-4 mb-4">
            <div class="p-3 bg-orange-50 rounded-full">
                <Icon icon="lucide:info" class="h-8 w-8 text-orange-600" />
            </div>
            <div>
                <h3 class="font-mono text-lg font-semibold">System Information</h3>
                <p class="font-mono text-sm text-neutral-600">About PiControl IoT</p>
            </div>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div class="text-center">
                <Icon icon="lucide:code" class="h-8 w-8 mx-auto text-blue-500 mb-2" />
                <h4 class="font-mono text-sm font-semibold">Framework</h4>
                <p class="font-mono text-xs text-neutral-600">SvelteKit + TypeScript</p>
            </div>
            <div class="text-center">
                <Icon icon="lucide:database" class="h-8 w-8 mx-auto text-green-500 mb-2" />
                <h4 class="font-mono text-sm font-semibold">Database</h4>
                <p class="font-mono text-xs text-neutral-600">PocketBase</p>
            </div>
            <div class="text-center">
                <Icon icon="lucide:terminal" class="h-8 w-8 mx-auto text-purple-500 mb-2" />
                <h4 class="font-mono text-sm font-semibold">Backend</h4>
                <p class="font-mono text-xs text-neutral-600">Go + Fiber</p>
            </div>
            <div class="text-center">
                <Icon icon="lucide:cpu" class="h-8 w-8 mx-auto text-red-500 mb-2" />
                <h4 class="font-mono text-sm font-semibold">Target</h4>
                <p class="font-mono text-xs text-neutral-600">Raspberry Pi + ESP32</p>
            </div>
        </div>
        
        <div class="mt-6 pt-4 border-t border-neutral-200 text-center">
            <p class="font-mono text-sm text-neutral-600">
                PiControl IoT - A comprehensive solution for managing and monitoring IoT devices
            </p>
        </div>
    </div>
</div>
