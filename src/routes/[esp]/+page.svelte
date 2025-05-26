<script lang="ts">
    let { data }: { data: { device: any } } = $props(); 
    let device = $state(data.device);

</script>

<div class="container mx-auto px-4 py-8 min-h-screen">
    <h1 class="font-mono text-2xl font-bold mb-4">Sensors for {device.device_name}</h1>
    <p class="mb-4 font-mono text-sm text-neutral-500">IP: {device.ip_addr}</p>
</div>