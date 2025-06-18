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
  <div class="bg-neutral-900 border border-neutral-800 p-4 rounded shadow-lg w-80">
    <h3 class="text-white font-mono text-sm mb-4">SSH Authentication</h3>
    <div class="mb-4">
      <label for="sshUsername" class="block text-neutral-400 text-xs font-mono mb-1">Username</label>
      <input 
        type="text" 
        id="sshUsername" 
        bind:value={username} 
        class="w-full bg-black border border-neutral-800 text-white px-2 py-1 text-sm font-mono focus:outline-none focus:border-neutral-600"
      />
    </div>  
    <div class="mb-4">
      <label for="sshHost" class="block text-neutral-400 text-xs font-mono mb-1">Host IP Address</label>
      <input 
        type="text" 
        id="sshHost" 
        bind:value={host} 
        class="w-full bg-black border border-neutral-800 text-white px-2 py-1 text-sm font-mono focus:outline-none focus:border-neutral-600"
      />
    </div>
    <div class="mb-4">
      <label for="sshPassword" class="block text-neutral-400 text-xs font-mono mb-1">Password for {username}@{host}</label>
      <input 
        type="password" 
        id="sshPassword" 
        bind:value={password} 
        class="w-full bg-black border border-neutral-800 text-white px-2 py-1 text-sm font-mono focus:outline-none focus:border-neutral-600"
        autocomplete="current-password"
      />
    </div>
    {#if error}
      <div class="mb-2 text-xs text-red-400 font-mono">{error}</div>
    {/if}
    <div class="flex justify-end space-x-2">
      <button 
        class="px-3 py-1 text-xs font-mono text-neutral-300 hover:text-white"
        on:click={handleCancel}
        disabled={loading}
      >
        Cancel
      </button>
      <button 
        class="px-3 py-1 text-xs font-mono bg-neutral-800 text-white hover:bg-neutral-700"
        on:click={handleConnect}
        disabled={loading}
      >
        {loading ? 'Connecting...' : 'Connect'}
      </button>
    </div>
  </div>
</div>
{/if}
