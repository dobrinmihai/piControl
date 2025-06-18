<script lang="ts">
  export let show = false;
  export let username = 'root';
  export let host = '';
  export let password = '';
  export let loading = false;
  export let error = '';

  export let onCancel: () => void = () => {};
  export let onConnect: (detail: { username: string, host: string, password: string }) => void = () => {};

  function handleCancel() {
    onCancel();
  }
  function handleConnect() {
    onConnect({ username, host, password });
  }
</script>

{#if show}
<div class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50">
  <div class="bg-white border border-neutral-800 p-6 rounded-lg shadow-lg w-96">
    <h3 class="text-black font-mono text-lg font-bold mb-6">SSH Authentication</h3>
    <div class="mb-5">
      <label for="sshUsername" class="block text-neutral-700 text-xs font-mono mb-1">Username</label>
      <input 
        type="text" 
        id="sshUsername" 
        bind:value={username} 
        class="w-full bg-white border border-neutral-800 text-black px-3 py-2 text-base font-mono rounded focus:outline-none focus:border-neutral-600"
      />
    </div>  
    <div class="mb-5">
      <label for="sshHost" class="block text-neutral-700 text-xs font-mono mb-1">Host IP Address</label>
      <input 
        type="text" 
        id="sshHost" 
        bind:value={host} 
        class="w-full bg-white border border-neutral-800 text-black px-3 py-2 text-base font-mono rounded focus:outline-none focus:border-neutral-600"
      />
    </div>
    <div class="mb-5">
      <label for="sshPassword" class="block text-neutral-700 text-xs font-mono mb-1">Password for {username}@{host}</label>
      <input 
        type="password" 
        id="sshPassword" 
        bind:value={password} 
        class="w-full bg-white border border-neutral-800 text-black px-3 py-2 text-base font-mono rounded focus:outline-none focus:border-neutral-600"
        autocomplete="current-password"
      />
    </div>
    {#if error}
      <div class="mb-3 text-xs text-red-500 font-mono">{error}</div>
    {/if}
    <div class="flex justify-end space-x-3 mt-6">
      <button 
        class="px-4 py-2 text-xs font-mono border border-neutral-800 bg-transparent text-black hover:bg-neutral-200 rounded"
        on:click={handleCancel}
        disabled={loading}
      >
        Cancel
      </button>
      <button 
        class="px-4 py-2 text-xs font-mono bg-black text-white hover:bg-neutral-800 rounded border border-neutral-800"
        on:click={handleConnect}
        disabled={loading}
      >
        {loading ? 'Connecting...' : 'Connect'}
      </button>
    </div>
  </div>
</div>
{/if}
